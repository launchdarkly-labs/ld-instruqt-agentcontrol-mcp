#!/usr/bin/env python3
"""Force a guarded-rollout rollback by emitting low brand-voice scores.

For presenter-driven demos: when the rollout's organic data is too slow
to trigger an automatic rollback, run this to flood
otto-brand-voice-score with near-zero values tied specifically to the
Stiff variation. Within a minute or two, the guarded rollout's
regression detection should fire.

Each iteration:
  1. Builds a fresh per-event context.
  2. Evaluates otto-assistant for that context. With a guarded rollout
     active, LD randomizes the context into either control or test —
     and *records the bucket against the metric pipeline*. A raw
     ld_client.track() without an eval first wouldn't attribute the
     event to a variation at all.
  3. If the eval served the Nova-Pro Stiff variation, emits a 0.0
     brand-voice-score. If it served any other variation, skips so
     the control's score stays clean.

So N controls the iteration count; the actual emitted-event count
depends on the rollout's current allocation (e.g., 10% Stiff -> ~N/10
sabotage hits).

Usage:
    sabotage.py [N]

Where N is the number of iterations (default 600 -- typically yields
~60 effective sabotage events at the first rollout stage).
"""
from __future__ import annotations

import json
import os
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
STIFF_MODEL_NAME = "nova-pro"  # the Stiff variation's model_config_key.model_id


def main() -> int:
    sdk_key = os.environ.get("LD_SDK_KEY")
    if not sdk_key:
        print("ERROR: LD_SDK_KEY not set", file=sys.stderr)
        return 1

    n = int(sys.argv[1]) if len(sys.argv) > 1 else 600

    ld_client = LDClient(LDConfig(sdk_key))
    if not ld_client.is_initialized():
        print("WARN: LD client did not initialize", file=sys.stderr)
    ai_client = LDAIClient(ld_client)

    print(f"Sabotage: evaluating {n} contexts; emitting 0.0 only when Stiff is served...")
    hits = 0
    for i in range(n):
        ctx = Context.builder(f"sabotage-{uuid4().hex[:8]}").set("tier", "free").build()
        cfg = ai_client.completion_config(
            OTTO_CONFIG_KEY, ctx, AICompletionConfigDefault(enabled=False)
        )
        if cfg.enabled and cfg.model is not None and cfg.model.name == STIFF_MODEL_NAME:
            ld_client.track("otto-brand-voice-score", ctx, None, 0.0)
            hits += 1
        else:
            ld_client.track("otto-brand-voice-score", ctx, None, 9.0)

        if (i + 1) % 50 == 0:
            print(f"  {i + 1}/{n} (hits: {hits})")

    ld_client.flush()
    ld_client.close()
    print(f"Done. {hits} effective sabotage events out of {n} iterations.")
    print("Watch the rollout for a regression detection event.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
