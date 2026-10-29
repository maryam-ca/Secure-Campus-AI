"""
Checks whether the Firestore rules PUBLISHED in your Firebase project include
the rules this app needs (student reports, book lock history).

It signs in as the demo librarian from CREDENTIALS.md (the same way the app
does) and only READS: it makes a few read requests and prints the HTTP result
of each. Nothing is written or changed, and no passwords, tokens or document
contents are printed.

    python scripts/check_live_rules.py

Reading the result:
    issueReports / lockHistory  HTTP 200  -> the new rules are published, locking and reports work
    issueReports / lockHistory  HTTP 403  -> the project still has the OLD rules: publish
                                              firebase/firestore.rules (Firebase console ->
                                              Firestore Database -> Rules -> paste -> Publish)
"""

from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def call(url: str, body: dict | None = None, token: str | None = None) -> tuple[int, dict]:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except Exception:  # noqa: BLE001
            return e.code, {}


def librarian_login() -> tuple[str, str]:
    role = None
    for line in (ROOT / "CREDENTIALS.md").read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            role = line[3:].strip().lower()
        m = re.match(r"\s*([\w.+-]+@[\w.-]+)\s*/\s*(\S+)", line)
        if m and role == "librarian":
            return m.group(1), m.group(2)
    raise SystemExit("No librarian account found in CREDENTIALS.md")


def main() -> int:
    opts = (ROOT / "mobile/lib/firebase_options.dart").read_text(encoding="utf-8")
    api_key = re.search(r"apiKey:\s*'([^']+)'", opts).group(1)
    project = re.search(r"projectId:\s*'([^']+)'", opts).group(1)
    email, password = librarian_login()
    print("Firebase project:", project)

    status, data = call(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}",
        {"email": email, "password": password, "returnSecureToken": True},
    )
    if status != 200:
        print("Librarian sign-in failed:", data.get("error", {}).get("message"))
        return 1
    token = data["idToken"]
    base = f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents"

    def probe(label: str, path: str) -> bool:
        s, d = call(f"{base}/{path}?pageSize=1", token=token)
        ok = s == 200
        print(f"  {label:44s} HTTP {s} {'ok' if ok else d.get('error', {}).get('status', '')}")
        return ok

    print("Read checks as the librarian:")
    probe("books (existing rule)", "books")
    probe("libraryIssues (existing rule)", "libraryIssues")
    reports = probe("issueReports (student reports rule)", "issueReports")
    history = probe("books/BOOK-001/lockHistory (lock history rule)", "books/BOOK-001/lockHistory")
    config = probe("config (campus location rule)", "config")

    if reports and history:
        print("\nThe new rules are PUBLISHED. Locking books and student reports should work.")
        return 0
    print("\nThe new rules are NOT published yet. Publish firebase/firestore.rules in the Firebase console\n"
          "(Firestore Database -> Rules -> paste the whole file -> Publish), then run this again.")
    return 2


if __name__ == "__main__":
    sys.exit(main())
