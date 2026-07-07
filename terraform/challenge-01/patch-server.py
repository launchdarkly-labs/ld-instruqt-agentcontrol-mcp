#!/usr/bin/env python3
"""Replace Challenge 01's paste-block stub in server.py with the wired-up code.

Used by `solve-workstation` to bring a skipped learner to the correct end-state.
Idempotent: if the file already contains the post-paste code, this is a no-op.
"""
import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "challenge-01" / "server-paste.py"

BEGIN_MARKER = "    # ─────────────────────────────────────────────────────────────────────\n    # Challenge 01 paste block"
END_MARKER = "    # ─── End Challenge 01 paste block ────────────────────────────────────"

# Signature keyed off the paste's stable header comment. Idempotency:
# post-patch server.py contains this line; pre-patch server.py does not.
SIGNATURE = "# ─── Challenge 01: wire Otto to /chat"


def main() -> int:
    text = SERVER_PY.read_text()
    paste = PASTE_FILE.read_text()

    if SIGNATURE in text:
        print("server.py already wired — no patch needed.")
        return 0

    b = text.find(BEGIN_MARKER)
    e = text.find(END_MARKER)
    if b == -1 or e == -1:
        print(f"ERROR: paste markers not found in {SERVER_PY}", file=sys.stderr)
        return 1

    end_of_end_line = text.find("\n", e) + 1
    new_text = text[:b] + paste + text[end_of_end_line:]
    SERVER_PY.write_text(new_text)
    print(f"Patched {SERVER_PY}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
