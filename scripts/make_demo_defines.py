"""
Builds mobile/demo_accounts.json from CREDENTIALS.md so the debug app can show
a "Demo accounts" list on the login screen (tap = sign in).

Both files are git-ignored. The passwords reach the app ONLY as a build-time
--dart-define, never as source code, and the list is shown only in debug
builds (kDebugMode). Do not build a release APK with this file.

Usage (from the repo root):
    python scripts/make_demo_defines.py
    cd mobile
    flutter build apk --debug --dart-define-from-file=demo_accounts.json
    # or: flutter run --dart-define-from-file=demo_accounts.json
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "CREDENTIALS.md"
TARGET = ROOT / "mobile" / "demo_accounts.json"

# "## Heading" in CREDENTIALS.md -> role shown in the app
ROLE_BY_HEADING = {
    "admin": "admin",
    "students": "student",
    "librarian": "librarian",
    "security staff": "security",
    "security": "security",
    "driver": "driver",
}
LINE = re.compile(r"^\s*([\w.+-]+@[\w.-]+\.\w+)\s*/\s*(\S+)\s*$")


def label_for(role: str, email: str) -> str:
    local = email.split("@")[0]
    if role == "student":
        return "Student " + local.split("-")[-1]  # fa23-bse-007 -> Student 007
    return role.capitalize()


def main() -> int:
    if not SOURCE.exists():
        print(f"{SOURCE} not found", file=sys.stderr)
        return 1

    accounts = []
    role = None
    for raw in SOURCE.read_text(encoding="utf-8").splitlines():
        if raw.startswith("## "):
            role = ROLE_BY_HEADING.get(raw[3:].strip().lower())
            continue
        m = LINE.match(raw)
        if role and m:
            email, password = m.groups()
            accounts.append({"role": role, "label": label_for(role, email), "email": email, "password": password})

    if not accounts:
        print("No 'email / password' lines found under role headings.", file=sys.stderr)
        return 1

    TARGET.write_text(json.dumps({"DEMO_ACCOUNTS": json.dumps(accounts)}, indent=2), encoding="utf-8")
    roles = sorted({a["role"] for a in accounts})
    print(f"Wrote {len(accounts)} demo accounts ({', '.join(roles)}) to {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
