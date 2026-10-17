"""
Seeds the initial practical dataset described in the project spec
(section 47): 10 test students, 5 books, 1 bus, 1 driver, a handful of
courses, and bus stops - as ordinary Firestore/Auth/RTDB records that
Admin can edit afterward, not as hardcoded app data.


Reuses iris_ai/app/firebase_client.py::create_account() for every
account created here (fixed after audit - see docs/AUDIT_REPORT.md
"Security Issues" #4), rather than duplicating account-creation logic:
that function is the one with the race-safe, transactional
registration-number uniqueness reservation, and having two independent
implementations of "create a Firebase Auth user + profile doc" risked
them silently drifting apart.

Requires:
    GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
    FIREBASE_PROJECT_ID=your-project-id
    FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.<region>.firebasedatabase.app

Usage:
    python scripts/seed_firebase.py
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "iris_ai"))

from app import firebase_client  # noqa: E402  (path insert must run first)
from app.config import settings  # noqa: E402
from firebase_admin import db as rtdb  # noqa: E402

# NOTE (fixed after a real run-time bug): this used to check
# os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") directly, which is
# NOT the same thing as "the value is set in .env" - pydantic-settings
# (used by app.config.settings) loads .env into its own Settings
# object, it does not inject those values into the process's actual
# os.environ. Checking `settings.GOOGLE_APPLICATION_CREDENTIALS`
# instead is what actually reflects what was in .env.
if not settings.GOOGLE_APPLICATION_CREDENTIALS:
    raise SystemExit(
        "GOOGLE_APPLICATION_CREDENTIALS is not set in .env (at the repo root). "
        "Run this script from the repo root, not from inside iris_ai/ or mobile/."
    )

firebase_client.init_firebase()
fs = firebase_client.db()
DATABASE_URL = settings.FIREBASE_DATABASE_URL

PROGRAM = "BSE"
INTAKE = "FA23"

STUDENTS = [
    {"n": i, "name": name}
    for i, name in enumerate([
        "Ayesha Khan", "Bilal Ahmed", "Sara Malik", "Hamza Iqbal", "Zainab Rauf",
        "Usman Tariq", "Mehak Fatima", "Ali Raza", "Nimra Shah", "Omar Farooq",
    ], start=1)
]

COURSES = [
    {"id": "SE",  "name": "Software Engineering"},
    {"id": "AI",  "name": "Artificial Intelligence"},
    {"id": "DBS", "name": "Database Systems"},
    {"id": "CN",  "name": "Computer Networks"},
    {"id": "SQE", "name": "Software Quality Engineering"},
    {"id": "FYP", "name": "Final Year Project"},
]

BOOKS = [
    {"id": "BOOK-001", "title": "Introduction to Algorithms", "author": "Cormen, Leiserson, Rivest, Stein", "category": "Computer Science"},
    {"id": "BOOK-002", "title": "Computer Networking: A Top-Down Approach", "author": "Kurose & Ross", "category": "Networking"},
    {"id": "BOOK-003", "title": "Database System Concepts", "author": "Silberschatz, Korth, Sudarshan", "category": "Databases"},
    {"id": "BOOK-004", "title": "Artificial Intelligence: A Modern Approach", "author": "Russell & Norvig", "category": "AI"},
    {"id": "BOOK-005", "title": "Software Engineering", "author": "Ian Sommerville", "category": "Software Engineering"},
]

BUS_STOPS = [
    {"id": "STOP-01", "name": "Main Gate", "lat": 33.6844, "lng": 73.0479, "order": 1},
    {"id": "STOP-02", "name": "Hostel Block", "lat": 33.6860, "lng": 73.0512, "order": 2},
    {"id": "STOP-03", "name": "City Chowk", "lat": 33.6901, "lng": 73.0601, "order": 3},
]


def main() -> None:
    print("== Admin ==")
    r = firebase_client.create_account(email="admin@securecampus.edu.pk", name="System Admin", role="admin")
    print(f"  [admin] {r['email']}  temp password: {r['temporaryPassword']}")

    print("\n== Courses ==")
    for c in COURSES:
        fs.collection("courses").document(c["id"]).set({
            "id": c["id"], "name": c["name"], "schedule": [],
        }, merge=True)
        print(f"  {c['id']} - {c['name']}")

    print("\n== Students (Firebase Auth + Firestore, via firebase_client.create_account) ==")
    for s in STUDENTS:
        reg_no = f"{INTAKE}-{PROGRAM}-{s['n']:03d}"
        email = f"{reg_no.lower()}@securecampus.edu.pk"
        result = firebase_client.create_account(
            email=email, name=s["name"], role="student",
            student_fields={
                "registrationNumber": reg_no, "program": PROGRAM, "semester": 5,
                "courses": [c["id"] for c in COURSES],
            },
        )
        print(f"  [student] {email}  temp password: {result['temporaryPassword']}")

    print("\n== Librarian ==")
    r = firebase_client.create_account(email="librarian@securecampus.edu.pk", name="Library Desk", role="librarian")
    print(f"  [librarian] {r['email']}  temp password: {r['temporaryPassword']}")

    print("\n== Security Staff ==")
    r = firebase_client.create_account(email="security@securecampus.edu.pk", name="Gate Security", role="security")
    print(f"  [security] {r['email']}  temp password: {r['temporaryPassword']}")

    print("\n== Driver ==")
    r = firebase_client.create_account(email="driver@securecampus.edu.pk", name="Bus Driver", role="driver")
    driver_uid = r["uid"]
    print(f"  [driver] {r['email']}  temp password: {r['temporaryPassword']}")

    print("\n== Books ==")
    for b in BOOKS:
        fs.collection("books").document(b["id"]).set({**b, "available": True})
        print(f"  {b['id']} - {b['title']}")

    print("\n== Bus stops ==")
    for stop in BUS_STOPS:
        fs.collection("busStops").document(stop["id"]).set(stop)
        print(f"  {stop['id']} - {stop['name']}")

    print("\n== Bus + driver assignment ==")
    fs.collection("bus").document("BUS-001").set({
        "id": "BUS-001", "driverUid": driver_uid, "active": True,
    })
    if DATABASE_URL:
        rtdb.reference(f"driverAssignments/{driver_uid}").set("BUS-001")

    print("\nDone.")


if __name__ == "__main__":
    main()