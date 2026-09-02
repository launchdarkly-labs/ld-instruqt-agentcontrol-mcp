#!/usr/bin/env python3
"""Synthetic traffic for the prompt-experiment lab (Evaluate ch06).

Evaluates otto-assistant in a loop, then emits an `otto-brand-voice-score`
event biased per variation. Does NOT call Bedrock — synthetic scoring is
enough to make the experiment converge inside the lab's time budget, and
the experiment view only consumes the LD-side metric events.

Variation detection: both otto-born and otto-recommender use the same
model (Haiku), so cfg.model.name doesn't distinguish them. Instead we
substring-match on the resolved system prompt — the phrase
"complementary item" lives only in otto-recommender's prompt.

Score distributions (mean, std):
  otto-born          (0.65, 0.08)  -- terse, concise
  otto-recommender   (0.75, 0.08)  -- one-sentence delta encouraging
                                      proactive recommendations
Both clipped to [0.0, 1.0]. The 0.10 mean delta is enough to land a
clear (but not screaming) winner within ~60-90s of running experiment.

Runs continuously until SIGTERM/SIGINT. Launch with nohup; kill with
`pkill -f experiment_traffic.py`.
"""
from __future__ import annotations

import os
import random
import signal
import sys
import time
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv

APP_ENV = Path(__file__).resolve().parent.parent / "app" / ".env"
load_dotenv(dotenv_path=APP_ENV, override=True)

from ldai import AICompletionConfigDefault, LDAIClient  # noqa: E402
from ldclient import Context, LDClient  # noqa: E402
from ldclient.config import Config as LDConfig  # noqa: E402

OTTO_CONFIG_KEY = "otto-assistant"
METRIC_KEY = "otto-brand-voice-score"
SLEEP_SECONDS = float(os.getenv("EXPERIMENT_SLEEP", "0.5"))

SCORES = {
    "recommender": (0.75, 0.08),
    "born":        (0.65, 0.08),
}


def variation_kind(cfg) -> str:
    """Substring-detect which variation was served by inspecting the prompt."""
    for m in (cfg.messages or []):
        if m.role == "system" and "complementary item" in m.content:
            return "recommender"
    return "born"


def main() -> int:
    sdk_key = os.environ.get("LD_SDK_KEY")
    if not sdk_key:
        print("ERROR: LD_SDK_KEY not set", file=sys.stderr)
        return 1

    ld_client = LDClient(LDConfig(sdk_key))
    if not ld_client.is_initialized():
        print("WARN: LD client did not initialize in time", file=sys.stderr)
    ai_client = LDAIClient(ld_client)

    stop = False

    def handle_signal(_signum, _frame) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    sessions = 0
    while not stop:
        ctx = Context.builder(f"sim-{uuid4().hex[:10]}").set("tier", "free").build()
        cfg = ai_client.completion_config(
            OTTO_CONFIG_KEY, ctx, AICompletionConfigDefault(enabled=False)
        )

        if not cfg.enabled or cfg.model is None:
            time.sleep(SLEEP_SECONDS)
            continue

        kind = variation_kind(cfg)
        mean, std = SCORES[kind]
        score = max(0.0, min(1.0, random.gauss(mean, std)))

        ld_client.track(METRIC_KEY, ctx, None, score)
        sessions += 1
        if sessions % 50 == 0:
            print(f"[{sessions}] last: kind={kind} score={score:.2f}", flush=True)

        time.sleep(SLEEP_SECONDS)

    ld_client.flush()
    ld_client.close()
    print(f"experiment_traffic: exiting after {sessions} sessions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
