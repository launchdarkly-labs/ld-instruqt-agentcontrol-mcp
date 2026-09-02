"""ToggleWear server.

The /chat endpoint contains a marked block that the learner replaces in
Challenge 01 to wire Otto up to the otto-assistant Config and Bedrock.
Imports, clients, helpers, and turn-cap logic are all pre-wired.
"""
import logging
import os
import threading
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


@app.get("/")
def index():
    return FileResponse(STATIC_DIR / "index.html")


@app.post("/chat/reset")
def chat_reset(req: ChatResetRequest):
    """Clear server-side history and turn count for this session so the
    learner can start a fresh chat without refreshing the page."""
    with _state_lock:
        _turns.pop(req.session_id, None)
        _history.pop(req.session_id, None)
    log.info("chat reset session=%s", req.session_id)
    return {"ok": True}


@app.get("/healthz")
def healthz():
    return {"ok": True, "otto_config": OTTO_CONFIG_KEY, "region": AWS_REGION}


@app.get("/api/features")
def api_features(session_id: str, user_tier: str = "free"):
    # ─────────────────────────────────────────────────────────────────────
    # CodeControl Challenge 01 paste block — replace this stub with flag evaluation.
    # The lab instructions tell you exactly what to put between these
    # markers. Until you do, the storefront shows no feature flag sections.
    # ─────────────────────────────────────────────────────────────────────
    return {"new_arrivals_enabled": False}
    # ─── End CodeControl Challenge 01 paste block ─────────────────────────


@app.post("/api/track")
def api_track(session_id: str, event_key: str):
    # ─────────────────────────────────────────────────────────────────────
    # CodeControl Challenge 04 paste block — replace this stub with event tracking.
    # The lab instructions tell you exactly what to put between these
    # markers. Until you do, click events are silently dropped.
    # ─────────────────────────────────────────────────────────────────────
    return {"ok": True}
    # ─── End CodeControl Challenge 04 paste block ─────────────────────────


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
