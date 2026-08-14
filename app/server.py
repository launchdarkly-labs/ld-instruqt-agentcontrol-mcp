"""ToggleWear server.

The /chat endpoint contains a marked block that the learner replaces in
Challenge 01 to wire Otto up to the otto-assistant Config and Bedrock.
Imports, clients, helpers, and turn-cap logic are all pre-wired.

The human-review queue and its endpoints are also pre-wired, so Challenge 03's
paste block is just the decision logic. Nothing here reads LaunchDarkly; the
gate that decides what to enqueue is what the learner writes.
"""
import logging
import os
import threading
import uuid
from collections import defaultdict, deque
from pathlib import Path
from typing import Optional

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from ldai import AICompletionConfigDefault, LDAIClient, LDMessage
from ldclient import Context, LDClient
from ldclient.config import Config as LDConfig
from pydantic import BaseModel

# override=True so .env wins over stale LD_* values from a previous shell
# session. AWS credentials come from the BedrockProfile (set up via GCP→AWS
# federation), so we deliberately do NOT touch AWS_* in os.environ here.
load_dotenv(override=True)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("togglewear")

STATIC_DIR = Path(__file__).parent / "static"
OTTO_CONFIG_KEY = "otto-assistant"
TURN_LIMIT = int(os.getenv("LD_CHAT_TURN_LIMIT", "30"))
HISTORY_LIMIT = 20  # last N user/assistant messages per session

# ─── Human review (Challenge 03) ───────────────────────────────────────────
# The flag holding the score bands. Defaults here are the last-resort values
# used when LaunchDarkly is unreachable; the real ones live in the flag.
REVIEW_FLAG_KEY = "otto-review-thresholds"
REVIEW_DEFAULTS = {"auto": 0.8, "review": 0.5}
REVIEW_QUEUE_LIMIT = 50  # oldest entries are dropped past this

# What the customer sees instead of a held or suppressed answer.
HOLD_PLACEHOLDER = (
    "One moment — I'm having a colleague double-check this before I send it."
)
SUPPRESS_FALLBACK = (
    "I'd rather not guess at that one. Our support team can give you a proper "
    "answer — you can reach them from the Support link at the top of the page."
)
LD_SDK_KEY = os.environ["LD_SDK_KEY"]
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
AWS_PROFILE = os.getenv("AWS_PROFILE", "BedrockProfile")

ld_client = LDClient(LDConfig(LD_SDK_KEY))
ai_client = LDAIClient(ld_client)
# Explicit credentials — avoids the boto3 credential chain falling back to
# stale shared-credentials files, instance profiles, or SSO refresh attempts.
boto_session = boto3.Session(profile_name=AWS_PROFILE, region_name=AWS_REGION)
bedrock = boto_session.client("bedrock-runtime")

FALLBACK_CONFIG = AICompletionConfigDefault(enabled=False)

# LaunchDarkly's model config registry returns either a vendor-neutral name
# (e.g. "claude-sonnet-4-5") or the full Bedrock model ID (e.g.
# "anthropic.claude-sonnet-4-5-20250929-v1:0") depending on how the model
# config was created. Bedrock needs the US cross-region inference profile ID
# (with the `us.` prefix) for all of these in us-east-1. When the workshop
# adds a new model, add rows for both shapes here.
BEDROCK_MODEL_IDS = {
    # Vendor-neutral slugs (Terraform-created model_configs).
    "claude-sonnet-4-6": "us.anthropic.claude-sonnet-4-6",
    "claude-sonnet-4-5": "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
    "claude-haiku-4-5":  "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "nova-lite":         "us.amazon.nova-lite-v1:0",
    "nova-pro":          "us.amazon.nova-pro-v1:0",
    # Full in-region Bedrock IDs (UI-created model_configs).
    "anthropic.claude-sonnet-4-6":               "us.anthropic.claude-sonnet-4-6",
    "anthropic.claude-sonnet-4-5-20250929-v1:0": "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
    "anthropic.claude-haiku-4-5-20251001-v1:0":  "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "amazon.nova-lite-v1:0":                     "us.amazon.nova-lite-v1:0",
    "amazon.nova-pro-v1:0":                      "us.amazon.nova-pro-v1:0",
}


def resolve_bedrock_model(ld_model_name: str) -> str:
    """Map LD's vendor-neutral model name to a Bedrock model ID. Pass-through if unknown."""
    return BEDROCK_MODEL_IDS.get(ld_model_name, ld_model_name)

_turns: dict[str, int] = defaultdict(int)
_history: dict[str, deque] = defaultdict(lambda: deque(maxlen=HISTORY_LIMIT))
_state_lock = threading.Lock()

# Held responses awaiting a human decision, newest last. In-memory on purpose:
# the queue is a teaching device with a lab-length lifetime, and it shares the
# fate of _turns and _history above.
_review_queue: list[dict] = []
# Reviewer decisions the customer's widget hasn't picked up yet, per session.
_review_delivery: dict[str, list[str]] = defaultdict(list)
_review_lock = threading.Lock()


def _enqueue_review(
    session_id: str,
    question: str,
    answer: str,
    score: Optional[float],
    model: str,
) -> str:
    """Park a response for human review. Returns the review id."""
    review_id = uuid.uuid4().hex[:12]
    with _review_lock:
        _review_queue.append({
            "id": review_id,
            "session_id": session_id,
            "question": question,
            "answer": answer,
            "score": score,
            "model": model,
        })
        # Drop the oldest rather than growing without bound. A learner who
        # widens the band aggressively can fill this fast.
        while len(_review_queue) > REVIEW_QUEUE_LIMIT:
            _review_queue.pop(0)
    log.info("review queued id=%s session=%s score=%s", review_id, session_id, score)
    return review_id


def _remember(session_id: str, user_message: str, final_text: str) -> None:
    """Record a completed turn.

    Called once per request, after the judge and the review gate have run, with
    the text the customer actually received. Writing history here rather than
    inside the Bedrock call is deliberate: the gate can replace an answer with a
    placeholder or a fallback, and Otto's memory must match what was sent, not
    what he originally produced.
    """
    with _state_lock:
        _history[session_id].append(LDMessage(role="user", content=user_message))
        _history[session_id].append(LDMessage(role="assistant", content=final_text))


# ─── Challenge 02 and 03 fill these in ─────────────────────────────────────
#
# Both ship as stubs whose return values mean "not wired yet", so the app runs
# correctly at every stage: no score means the gate ships everything, which is
# exactly how Otto behaved before either challenge.


def score_response(
    req: "ChatRequest",
    assistant_text: str,
    model_id: str,
) -> Optional[float]:
    """Grade Otto's answer. Returns a score in 0.0-1.0, or None if not graded.

    The judge chapter replaces this body.
    """
    # ─── Challenge 02 judge: replace this body ───────────────────────────────
    return None


def gate_response(
    req: "ChatRequest",
    assistant_text: str,
    score: Optional[float],
    model_id: str,
) -> tuple[str, str]:
    """Decide what the customer sees. Returns (text_to_send, decision).

    `decision` is one of "ship", "hold", or "suppress".
    The review-gate chapter replaces this body.
    """
    # ─── Challenge 03 review gate: replace this body ─────────────────────────
    return assistant_text, "ship"


app = FastAPI(title="ToggleWear")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


class ChatRequest(BaseModel):
    message: str
    user_tier: str = "free"
    session_id: str


class ChatResponse(BaseModel):
    response: str
    turn: int
    turn_limit: int
    model: Optional[str] = None


class ChatResetRequest(BaseModel):
    session_id: str


class ReviewDecision(BaseModel):
    id: str
    action: str  # "approve" or "reject"
    answer: Optional[str] = None  # reviewer's edit; falls back to Otto's text


@app.get("/")
def index():
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/review")
def review_page():
    """The staff review surface, opened as its own Instruqt tab in Challenge 03.

    Deliberately a separate page from the storefront: the point of the chapter
    is that a different person with different authority sees a response before
    the customer does, and two surfaces make that structural rather than a panel
    on the same screen the shopper is using.
    """
    return FileResponse(STATIC_DIR / "review.html")


@app.post("/chat/reset")
def chat_reset(req: ChatResetRequest):
    """Clear server-side history and turn count for this session so the
    learner can start a fresh chat without refreshing the page."""
    with _state_lock:
        _turns.pop(req.session_id, None)
        _history.pop(req.session_id, None)
    with _review_lock:
        _review_delivery.pop(req.session_id, None)
        _review_queue[:] = [x for x in _review_queue if x["session_id"] != req.session_id]
    log.info("chat reset session=%s", req.session_id)
    return {"ok": True}


@app.get("/healthz")
def healthz():
    return {"ok": True, "otto_config": OTTO_CONFIG_KEY, "region": AWS_REGION}


# ─── Human review endpoints (Challenge 03) ─────────────────────────────────


@app.get("/review/queue")
def review_queue(session_id: Optional[str] = None):
    """What's waiting on a human. Backs the Staff Review page.

    Scoped to one session when `session_id` is given. Background traffic runs
    against /chat for the whole lab with a fresh session per request, so an
    unscoped queue buries the learner's own held response under bot items within
    a minute. `other_sessions` still reports the rest, so the queue reads as a
    real one rather than looking suspiciously empty.
    """
    with _review_lock:
        if session_id is None:
            return {"pending": list(_review_queue), "other_sessions": 0}
        mine = [x for x in _review_queue if x["session_id"] == session_id]
        return {"pending": mine, "other_sessions": len(_review_queue) - len(mine)}


@app.post("/review/resolve")
def review_resolve(req: ReviewDecision):
    """Approve (optionally edited) or reject a held response.

    An approval is queued for delivery to the customer's chat widget, which
    polls /review/updates. A rejection delivers the safe fallback instead.
    """
    with _review_lock:
        item = next((x for x in _review_queue if x["id"] == req.id), None)
        if item is None:
            return JSONResponse(status_code=404, content={"error": "unknown review id"})
        _review_queue.remove(item)

    if req.action == "approve":
        delivered = (req.answer or "").strip() or item["answer"]
        edited = bool((req.answer or "").strip()) and req.answer.strip() != item["answer"]
        outcome = "approved-edited" if edited else "approved"
    elif req.action == "reject":
        delivered = SUPPRESS_FALLBACK
        outcome = "rejected"
    else:
        return JSONResponse(status_code=400, content={"error": "action must be approve or reject"})

    with _review_lock:
        _review_delivery[item["session_id"]].append(delivered)

    # Otto's memory currently holds the placeholder the customer saw at request
    # time. Replace that last assistant turn with what the reviewer actually
    # approved, so an edit is what he carries into the next turn rather than
    # something nobody ever sent.
    with _state_lock:
        hist = _history.get(item["session_id"])
        if hist and hist[-1].role == "assistant":
            hist[-1] = LDMessage(role="assistant", content=delivered)

    # The reviewer's verdict is the ground truth the judge was estimating, so
    # it's worth measuring on its own.
    review_ctx = Context.builder(item["session_id"]).build()
    ld_client.track("otto-review-decision", review_ctx, {"outcome": outcome, "score": item["score"]}, 1)
    log.info("review resolved id=%s outcome=%s score=%s", item["id"], outcome, item["score"])

    return {"ok": True, "outcome": outcome}


@app.get("/review/updates")
def review_updates(session_id: str):
    """Drain any reviewer-approved messages for this session.

    The chat widget polls this while a response is held, so an approval shows
    up in the customer's transcript without a page refresh.
    """
    with _review_lock:
        messages = _review_delivery.pop(session_id, [])
        held = any(x["session_id"] == session_id for x in _review_queue)
    return {"messages": messages, "waiting": held}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    with _state_lock:
        _turns[req.session_id] += 1
        turn = _turns[req.session_id]

    if turn > TURN_LIMIT:
        return JSONResponse(
            status_code=429,
            content={
                "response": (
                    "You have reached the demo chat limit for this session. "
                    "Refresh the page to start a new session."
                ),
                "turn": turn,
                "turn_limit": TURN_LIMIT,
            },
        )

    # ─────────────────────────────────────────────────────────────────────
    # Challenge 01 paste block — replace this stub with real Otto code.
    # The lab instructions tell you exactly what to put between these
    # markers. Until you do, Otto returns a canned not-wired-up response.
    # ─────────────────────────────────────────────────────────────────────
    assistant_text = (
        "Otto isn't wired up yet. Complete Challenge 01 to bring him to life."
    )
    model_id = "(unwired)"
    log.info(
        "chat session=%s tier=%s turn=%d model=%s",
        req.session_id, req.user_tier, turn, model_id,
    )
    # ─── End Challenge 01 paste block ────────────────────────────────────

    # Grade it (Challenge 02), then decide who sees it (Challenge 03). Both are
    # no-ops until those challenges fill in the stubs above.
    brand_voice_score = score_response(req, assistant_text, model_id)
    assistant_text, decision = gate_response(
        req, assistant_text, brand_voice_score, model_id
    )

    # Record the turn last, with the text the customer actually received.
    _remember(req.session_id, req.message, assistant_text)

    if decision != "ship":
        log.info(
            "chat session=%s turn=%d decision=%s score=%s",
            req.session_id, turn, decision, brand_voice_score,
        )

    return ChatResponse(
        response=assistant_text,
        turn=turn,
        turn_limit=TURN_LIMIT,
        model=model_id,
    )


def _bedrock_user_message(code: Optional[str]) -> str:
    if code in ("ThrottlingException", "ServiceQuotaExceededException"):
        return "Otto is a little overwhelmed right now. Please try again in a few seconds."
    if code == "AccessDeniedException":
        return "Otto can't reach his model — please check AWS credentials and Bedrock model access."
    if code == "ValidationException":
        return "Otto's Config has an invalid setting. Please verify the model ID and variation."
    return "Otto hit an unexpected error. Please try again."


def _extract_text(response: dict) -> str:
    try:
        return response["output"]["message"]["content"][0]["text"]
    except (KeyError, IndexError, TypeError):
        return "Otto received a response in an unexpected format."


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=3000)
