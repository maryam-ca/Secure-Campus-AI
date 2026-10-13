"""
SecureCampus scheduled Cloud Functions.

This is the fix for the audit finding under "Library Overdue" (spec §14,
docs/AUDIT_REPORT.md #14 / §26 "PARTIALLY COMPLETE"): overdue *detection*
was already real and live (computed client-side from actual dates, see
mobile/lib/models/dashboard_models.dart::LibraryIssueModel.status), but
nothing ever actually sent the notification a student is supposed to
receive. A student had to open the app and look to find out.

A scheduled Cloud Function is the right current mechanism for this
specifically because it runs server-side on a timer, independent of
whether any student ever opens the app - which a client-side check
fundamentally cannot do. Python is used here (not Node.js) to keep the
whole backend in one language, consistent with iris_ai/ and bus_eta/,
and because `firebase-functions`' Python support (2nd gen) is a fully
supported, current, official option - not a workaround.

Deploy with (from the repo root):
    firebase deploy --only functions

Local syntax/import verification (this repository's build environment
has no way to actually invoke a scheduled trigger or connect to a real
Firebase project, so this is as far as it could be verified before
shipping - see docs/AUDIT_REPORT.md "Device/Project-Dependent Items"):
    cd functions
    pip install -r requirements.txt --break-system-packages
    python -c "import main"
"""

from __future__ import annotations

import datetime as dt

import firebase_admin
from firebase_admin import firestore, messaging
from firebase_functions import logger, scheduler_fn

firebase_admin.initialize_app()


@scheduler_fn.on_schedule(schedule="0 * * * *")  # every hour, on the hour
def check_overdue_books(event: scheduler_fn.ScheduledEvent) -> None:
    """Finds every libraryIssues doc that is (a) not yet returned and
    (b) past its expiryDate, and sends the overdue notification exactly
    once per issue - dedup is a real stored `overdueNotifiedAt` field,
    not a display-only badge, so a student is never re-notified every
    hour for the same overdue book."""
    db = firestore.client()
    now = dt.datetime.now(dt.timezone.utc)

    # Single range filter (expiryDate) + single equality filter
    # (returned) - no composite index needed beyond what's already in
    # firebase/firestore.indexes.json for this collection's other query.
    overdue_candidates = (
        db.collection("libraryIssues")
        .where("returned", "==", False)
        .where("expiryDate", "<", now)
        .stream()
    )

    notified_count = 0
    for doc in overdue_candidates:
        data = doc.to_dict() or {}

        if data.get("overdueNotifiedAt") is not None:
            continue  # already notified for this specific issue - real dedup

        student_id = data.get("studentId")
        if not student_id:
            logger.warn(f"libraryIssues/{doc.id} has no studentId - skipping")
            continue

        book_title = data.get("bookTitle", "your book")
        message = (
            f'Your book "{book_title}" was due back and is now overdue. '
            f"Please return it to the library. Fine: Rs. 100 "
            f"(informational only - no online payment)."
        )

        db.collection("notifications").add({
            "recipient": student_id,
            "title": "Library Reminder",
            "message": message,
            "type": "LIBRARY_OVERDUE",
            "isRead": False,
            "metadata": {"issueId": doc.id, "bookId": data.get("bookId", "")},
            "createdAt": firestore.SERVER_TIMESTAMP,
        })

        # Mark this issue as notified BEFORE attempting the push send -
        # a failed push must not cause a retry storm of duplicate
        # in-app notifications on the next hourly run.
        doc.reference.update({"overdueNotifiedAt": firestore.SERVER_TIMESTAMP})

        user_doc = db.collection("users").document(student_id).get()
        token = (user_doc.to_dict() or {}).get("fcmToken") if user_doc.exists else None
        if token:
            try:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title="Library Reminder",
                        body=f'"{book_title}" is overdue - please return it.',
                    ),
                    token=token,
                ))
            except Exception as exc:  # noqa: BLE001 - log and keep processing the rest
                logger.warn(f"FCM send failed for student {student_id}: {exc}")

        notified_count += 1

    logger.info(f"check_overdue_books: notified {notified_count} student(s) this run")
