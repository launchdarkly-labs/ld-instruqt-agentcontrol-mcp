#!/usr/bin/env python3
"""Inject Evaluate ch04's claim-accuracy-judge integration into server.py.

Looks for the same marker comment that ch03 used (Build's Challenge-01
paste places it). Idempotent: if the file already contains an
otto-claim-accuracy-judge call, this is a no-op. Coexists with ch03's
brand-voice judge block — both end up below the marker.
"""
import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "evaluate-04" / "judge-server-paste.py"
MARKER = "    # ─── Challenge 07 judge injects below this marker ──────────────────────"
# Signature keyed off the paste's stable header comment. Prior value
# was a snippet of the ai_client.judge_config call, which would break
# idempotency if the paste's call shape were ever reformatted.
SIGNATURE = "# ─── Evaluate 04: product-claim accuracy judge"


def main() -> int:
    text = SERVER_PY.read_text()
    paste = PASTE_FILE.read_text()

    if SIGNATURE in text:
        print("server.py already has the claim-accuracy judge integration — no patch needed.")
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
    print(f"Patched {SERVER_PY} with claim-accuracy judge integration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
