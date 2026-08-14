#!/usr/bin/env python3
"""Fill in Challenge 02's brand-voice judge in server.py.

server.py ships a `score_response()` stub whose body is a marker comment plus
`return None`. This replaces that body with the real judge call. Idempotent: if
the file already contains the paste's signature comment, this is a no-op.

Unlike a bare insert-after-marker patch, replacing a whole function body means
the result has one obvious contract — the signature — rather than depending on
which local variables an earlier paste happened to leave behind.
"""
import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "challenge-02" / "judge-server-paste.py"
MARKER = "    # ─── Challenge 02 judge: replace this body ───────────────────────────────"
STUB_RETURN = "    return None"
SIGNATURE = "# ─── Challenge 02: brand-voice judge"


def main() -> int:
    text = SERVER_PY.read_text()
    paste = PASTE_FILE.read_text()

    if SIGNATURE in text:
        print("server.py already has the brand-voice judge — no patch needed.")
        return 0

    if MARKER not in text:
        print(
            "ERROR: score_response stub marker not found in server.py. "
            "Is this the shipped server.py?",
            file=sys.stderr,
        )
        return 1

    start = text.find(MARKER)
    after_marker = text.find("\n", start) + 1
    if not text[after_marker:].startswith(STUB_RETURN):
        print(
            "ERROR: expected `return None` directly below the marker. "
            "The stub body has been edited; patch by hand.",
            file=sys.stderr,
        )
        return 1
    end = text.find("\n", after_marker) + 1

    SERVER_PY.write_text(text[:start] + paste + text[end:])
    print(f"Patched {SERVER_PY}: score_response() now calls the judge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
