#!/usr/bin/env python3
"""Fill in Challenge 03's review gate in server.py.

server.py ships a `gate_response()` stub whose body is a marker comment plus
`return assistant_text, "ship"`. This replaces that body with the real gate.
Idempotent via the paste's signature comment.

Independent of Challenge 02: the gate reads its `score` argument, so it works
whether or not the judge has been wired. An unwired judge returns None, and the
gate ships — which is exactly the fail-open behaviour it implements anyway.
"""
import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "challenge-03" / "review-server-paste.py"
MARKER = "    # ─── Challenge 03 review gate: replace this body ─────────────────────────"
STUB_RETURN = '    return assistant_text, "ship"'
SIGNATURE = "# ─── Challenge 03: human-in-the-loop review gate"


def main() -> int:
    text = SERVER_PY.read_text()
    paste = PASTE_FILE.read_text()

    if SIGNATURE in text:
        print("server.py already has the review gate — no patch needed.")
        return 0

    if MARKER not in text:
        print(
            "ERROR: gate_response stub marker not found in server.py. "
            "Is this the shipped server.py?",
            file=sys.stderr,
        )
        return 1

    start = text.find(MARKER)
    after_marker = text.find("\n", start) + 1
    if not text[after_marker:].startswith(STUB_RETURN):
        print(
            "ERROR: expected the stub `return assistant_text, \"ship\"` directly "
            "below the marker. The stub body has been edited; patch by hand.",
            file=sys.stderr,
        )
        return 1
    end = text.find("\n", after_marker) + 1

    SERVER_PY.write_text(text[:start] + paste + text[end:])
    print(f"Patched {SERVER_PY}: gate_response() now gates on the judge score")
    return 0


if __name__ == "__main__":
    sys.exit(main())
