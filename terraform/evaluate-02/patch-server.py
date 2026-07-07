#!/usr/bin/env python3
"""Inject Evaluate ch02's built-in-judge invocation into server.py.

server.py uses the completion_config + tracker + track_bedrock_converse_metrics
pattern (from Build's ch01 paste). That pattern doesn't automatically fire
attached judges the way create_model + run does. This patch inserts a block
that discovers the three built-in judges (Accuracy, Relevance, Toxicity),
reads their attached-and-sampling-rate state off otto-born, and invokes each
explicitly on every /chat call.

Idempotent: if `_BUILTIN_JUDGES_LOADED` already appears in server.py, no-op.
"""
import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "evaluate-02" / "builtin-judges-server-paste.py"
MARKER = "    # ─── Challenge 07 judge injects below this marker ──────────────────────"
# Signature keyed off the paste's stable header comment. The prior
# value `_BUILTIN_JUDGES_LOADED` never appeared in the paste, so this
# check always failed and re-runs duplicated the block.
SIGNATURE = "# ─── Evaluate 02: built-in judges"


def main() -> int:
    text = SERVER_PY.read_text()
    paste = PASTE_FILE.read_text()

    if SIGNATURE in text:
        print("server.py already has the built-in-judge invocation — no patch needed.")
        return 0

    if MARKER not in text:
        print(
            "ERROR: judge-marker not found in server.py. "
            "Has Build's Challenge-01 paste been applied?",
            file=sys.stderr,
        )
        return 1

    end_of_marker = text.find(MARKER) + len(MARKER)
    end_of_line = text.find("\n", end_of_marker)
    new_text = text[: end_of_line + 1] + paste + text[end_of_line + 1 :]
    SERVER_PY.write_text(new_text)
    print(f"Patched {SERVER_PY} with built-in judge invocation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
