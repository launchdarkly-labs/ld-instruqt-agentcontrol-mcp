#!/usr/bin/env python3
"""Inject Evaluate ch03's brand-voice-judge integration into server.py.

Looks for the marker comment left at the end of Build's Challenge-01 paste
block and inserts the judge code immediately after it. Idempotent: if the
file already contains an otto-brand-voice-judge call, this is a no-op.
"""
import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "evaluate-03" / "judge-server-paste.py"
MARKER = "    # ─── Challenge 07 judge injects below this marker ──────────────────────"
SIGNATURE = 'ai_client.judge_config(\n            "otto-brand-voice-judge"'


def main() -> int:
    text = SERVER_PY.read_text()
    paste = PASTE_FILE.read_text()

    if SIGNATURE in text:
        print("server.py already has the brand-voice judge integration — no patch needed.")
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
    print(f"Patched {SERVER_PY} with brand-voice judge integration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
