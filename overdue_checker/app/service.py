"""
Finds every libraryIssues doc that is not yet returned and past its
expiryDate, and sends the overdue notification exactly once per issue.
Free alternative to the Cloud Function version (functions/main.py) -
FCM pushes themselves are free on every Firebase plan; it's specifically
Cloud Functions + Cloud Scheduler that need Blaze, and this sidesteps
both by doing the "on a timer" part in this process's own loop instead.
"""

from __future__ import annotations

import datetime as dt
import logging

import firebase_admin
from firebase_admin import credentials, firestore, messaging

from app.config import settings

log = logging.getLogger("overdue_checker.service")

_app: firebase_admin.App | None = None


class FirebaseNotConfiguredError(RuntimeError):
    pass


def _init_firebase() -> firebase_admin.App:
    global _app
    if _app is not None:
        return _app
    if not settings.GOOGLE_APPLICATION_CREDENTIALS:
        raise FirebaseNotConfiguredError(
            "GOOGLE_APPLICATION_CREDENTIALS is not set. See .env.example / README Firebase setup."
        )
    cred = credentials.Certificate(settings.GOOGLE_APPLICATION_CREDENTIALS)
    _app = firebase_admin.initialize_app(cred, {
        "projectId": settings.FIREBASE_PROJECT_ID or None,
        "databaseURL": settings.FIREBASE_DATABASE_URL or None,
    })
    return _app


def run_once() -> int:
    """Runs one overdue-check pass. Returns how many students were
    notified this pass (0 is completely normal)."""
    _init_firebase()
    db = firestore.client()
    now = dt.datetime.now(dt.timezone.utc)

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
            continue

        student_id = data.get("studentId")
        if not student_id:
            log.warning("libraryIssues/%s has no studentId - skipping", doc.id)
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
            except Exception as exc:  # noqa: BLE001
                log.warning("FCM send failed for student %s: %s", student_id, exc)

        notified_count += 1
        log.info("Notified student %s about overdue book %r (issue %s)", student_id, book_title, doc.id)

    return notified_count