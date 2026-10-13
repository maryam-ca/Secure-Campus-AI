"""
One-time repair script: mirrors every existing users/{uid}.role from
Firestore into Realtime Database roles/{uid}, and the bus's driver
assignment into driverAssignments/{uid}.

Why this is needed: firebase_client.py::create_account() writes this
RTDB mirror automatically at account-creation time (RTDB rules can't
query Firestore directly, so this mirror is what lets database.rules.json
check a caller's role). If accounts were created while
FIREBASE_DATABASE_URL was empty/misconfigured in .env, that write was
silently skipped for each of them - this script finds every account
using the real Firestore data as the source of truth and re-writes the
RTDB mirror (harmless to re-run, even for accounts that already have it).

Usage (from the repo root, with .env correctly configured and the
iris_ai venv active):
    python scripts/backfill_rtdb_roles.py
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "iris_ai"))

from app import firebase_client  # noqa: E402
from app.config import settings  # noqa: E402
from firebase_admin import db as rtdb  # noqa: E402

if not settings.GOOGLE_APPLICATION_CREDENTIALS:
    raise SystemExit("GOOGLE_APPLICATION_CREDENTIALS is not set in .env (run this from the repo root).")
if not settings.FIREBASE_DATABASE_URL:
    raise SystemExit("FIREBASE_DATABASE_URL is not set in .env - nothing to backfill into.")

firebase_client.init_firebase()
fs = firebase_client.db()


def main() -> None:
    print("== Backfilling roles/{uid} from Firestore users/{uid}.role ==")
    count = 0
    for doc in fs.collection("users").stream():
        data = doc.to_dict() or {}
        role = data.get("role")
        if not role:
            print(f"  SKIPPED users/{doc.id} - no role field")
            continue
        rtdb.reference(f"roles/{doc.id}").set(role)
        print(f"  roles/{doc.id} = {role}  ({data.get('email', '')})")
        count += 1
    print(f"Backfilled {count} role(s).\n")

    print("== Backfilling driverAssignments/{uid} from bus/BUS-001 ==")
    bus_doc = fs.collection("bus").document("BUS-001").get()
    if bus_doc.exists:
        driver_uid = (bus_doc.to_dict() or {}).get("driverUid")
        if driver_uid:
            rtdb.reference(f"driverAssignments/{driver_uid}").set("BUS-001")
            print(f"  driverAssignments/{driver_uid} = BUS-001")
        else:
            print("  bus/BUS-001 has no driverUid field - nothing to backfill")
    else:
        print("  bus/BUS-001 does not exist yet - nothing to backfill")

    print("\nDone.")


if __name__ == "__main__":
    main()