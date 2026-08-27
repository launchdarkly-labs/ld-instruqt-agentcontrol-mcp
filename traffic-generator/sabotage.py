#!/usr/bin/env python3
"""Force a guarded-rollout regression by flooding the brand-voice metric.

Presenter / impatient-learner escape hatch for the "Trust But Verify"
chapter. background_traffic.py emits about one session every two seconds,
which is honest but can take longer than a lab slot to accumulate enough
samples for the rollout's regression detector to call it. This script
compresses that.

Each iteration:

  1. Builds a fresh per-event context.
  2. Evaluates otto-assistant for that context. This matters: with a
     guarded rollout running, the evaluation is what buckets the context
     into test or control and attributes the event to a variation. A bare
     ld_client.track() with no eval first produces an event the rollout
     can't attribute to either side, which is worse than useless — it
     dilutes both arms.
  3. Emits a brand-voice score matched to whichever variation actually
     served: near-zero for Stiff, healthy for anything else.

Both arms get scored on purpose. Emitting only for Stiff would leave the
control arm with no fresh samples, and a regression detector comparing a
flood of new bad data against a trickle of old good data is measuring the
clock as much as the model.

So N is an iteration count, not an event count for Stiff. At the first
rollout stage (10% to Stiff) roughly N/10 iterations land on Stiff.

Usage:
    sabotage.py [N]          # default 600

Scores are on the 0.0-1.0 scale the rest of the track uses — see
DECISIONS.md, "Judge scores are floats 0.0-1.0".
"""
from __future__ import annotations

import os
import random
import sys
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

# Matched loosely on purpose. The Stiff variation's model config is created by
# Terraform as "amazon.nova-pro-v1:0", but a learner who built it through the
# agent may have a differently-spelled Nova Pro sitting there instead. Anything
# with "nova" in the name is the risky arm in this lab — no other chapter uses
# a Nova model.
STIFF_MODEL_MARKER = "nova"

STIFF_SCORE = (0.05, 0.05)   # (mean, std) — the judge hates the corporate voice
CONTROL_SCORE = (0.85, 0.06) # what Born actually scores in practice


def _score(mean_std: tuple[float, float]) -> float:
    mean, std = mean_std
    return max(0.0, min(1.0, random.gauss(mean, std)))


def main() -> int:
    sdk_key = os.environ.get("LD_SDK_KEY")
    if not sdk_key:
        print("ERROR: LD_SDK_KEY not set. Is app/.env populated?", file=sys.stderr)
        return 1

    try:
        n = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    except ValueError:
        print(f"ERROR: '{sys.argv[1]}' is not a number.", file=sys.stderr)
        return 1

    ld_client = LDClient(LDConfig(sdk_key))
    if not ld_client.is_initialized():
        print("WARN: LD client did not initialize; events may not land.", file=sys.stderr)
    ai_client = LDAIClient(ld_client)

    print(f"Sabotage: evaluating {n} contexts, scoring each against {METRIC_KEY}...")
    stiff_hits = 0
    served_nothing = 0

    for i in range(n):
        ctx = Context.builder(f"sabotage-{uuid4().hex[:8]}").set("tier", "free").build()
        cfg = ai_client.completion_config(
            OTTO_CONFIG_KEY, ctx, AICompletionConfigDefault(enabled=False)
        )

        if not cfg.enabled or cfg.model is None:
            served_nothing += 1
            continue

        is_stiff = STIFF_MODEL_MARKER in (cfg.model.name or "").lower()
        ld_client.track(METRIC_KEY, ctx, None, _score(STIFF_SCORE if is_stiff else CONTROL_SCORE))
        stiff_hits += is_stiff

        if (i + 1) % 100 == 0:
            print(f"  {i + 1}/{n} (stiff: {stiff_hits})")

    ld_client.flush()
    ld_client.close()

    print(f"Done. {stiff_hits} of {n} iterations served the Stiff variation.")

    if served_nothing:
        print(
            f"NOTE: {served_nothing} evaluations returned a disabled Config. "
            "If that's most of them, otto-assistant isn't serving in Test.",
            file=sys.stderr,
        )
    if stiff_hits == 0:
        print(
            "WARNING: Stiff never served, so nothing was sabotaged. Either the "
            "rollout isn't running yet or it already rolled back. Ask the agent "
            "for the rollout's current status.",
            file=sys.stderr,
        )
        return 1

    print("Watch for a regression detection on the rollout within a minute or two.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
