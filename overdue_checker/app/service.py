"""
Library notifications, sent exactly once per issue each:

* DUE SOON - the book is still out and its return date is within
  DUE_SOON_HOURS (proposal 4.2: notify when the return date is near).
* OVERDUE  - the book is still out and the return date has passed.

Free alternative to the Cloud Function version (functions/, deprecated) -
FCM pushes themselves are free on every Firebase plan; it's Cloud Functions
+ Cloud Scheduler that need Blaze, so the timer lives in this process's
own loop (app/main.py) instead.

Dedup is a real stored field on the libraryIssues doc (dueSoonNotifiedAt,
overdueNotifiedAt), so a restart never re-sends.
"""

from __future__ import annotations

import datetime as dt
import logging

import firebase_admin
from firebase_admin import credentials, firestore, messaging

from app.config import settings

log = logging.getLogger("overdue_checker.service")

_app: firebase_admin.App | None = None

FINE_NOTE = "Fine: Rs. 100 (informational only - no online payment)."


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


def due_soon_message(book_title: str, expiry: dt.datetime, now: dt.datetime) -> str:
    hours = max(0, int((expiry - now).total_seconds() // 3600))
    when = "in less than an hour" if hours < 1 else f"in about {hours} hour{'s' if hours != 1 else ''}"
    return f'Your book "{book_title}" is due back {when}. Please return it to the library on time.'


def overdue_message(book_title: str) -> str:
    return (f'Your book "{book_title}" was due back and is now overdue. '
            f"Please return it to the library. {FINE_NOTE}")


def _notify_once(db, doc, data: dict, *, title: str, message: str, push_body: str,
                 notif_type: str, dedupe_field: str) -> bool:
    """Writes the in-app notification, marks the issue as notified, then
    tries the push. Marking happens BEFORE the push so a failed push can
    never cause a duplicate in-app notification on the next pass."""
    student_id = data.get("studentId")
    if not student_id:
        log.warning("libraryIssues/%s has no studentId - skipping", doc.id)
        return False

    db.collection("notifications").add({
        "recipient": student_id,
        "title": title,
        "message": message,
        "type": notif_type,
        "isRead": False,
        "metadata": {"issueId": doc.id, "bookId": data.get("bookId", "")},
        "createdAt": firestore.SERVER_TIMESTAMP,
    })
    doc.reference.update({dedupe_field: firestore.SERVER_TIMESTAMP})

    user_doc = db.collection("users").document(student_id).get()
    token = (user_doc.to_dict() or {}).get("fcmToken") if user_doc.exists else None
    if token:
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(title=title, body=push_body),
                token=token,
            ))
        except Exception as exc:  # noqa: BLE001
            log.warning("FCM send failed for student %s: %s", student_id, exc)
    return True


def notify_due_soon(db, now: dt.datetime) -> int:
    window_end = now + dt.timedelta(hours=settings.DUE_SOON_HOURS)
    candidates = (
        db.collection("libraryIssues")
        .where("returned", "==", False)
        .where("expiryDate", ">=", now)
        .where("expiryDate", "<=", window_end)
        .stream()
    )
    count = 0
    for doc in candidates:
        data = doc.to_dict() or {}
        if data.get("dueSoonNotifiedAt") is not None:
            continue
        book = data.get("bookTitle", "your book")
        expiry = data.get("expiryDate")
        if isinstance(expiry, dt.datetime):
            message = due_soon_message(book, expiry, now)
        else:
            message = f'Your book "{book}" is due back soon. Please return it on time.'
        if _notify_once(db, doc, data, title="Library Reminder", message=message,
                        push_body=f'"{book}" is due back soon.',
                        notif_type="LIBRARY_DUE_SOON", dedupe_field="dueSoonNotifiedAt"):
            count += 1
            log.info("Due-soon notice sent for %r (issue %s)", book, doc.id)
    return count


def notify_overdue(db, now: dt.datetime) -> int:
    candidates = (
        db.collection("libraryIssues")
        .where("returned", "==", False)
        .where("expiryDate", "<", now)
        .stream()
    )
    count = 0
    for doc in candidates:
        data = doc.to_dict() or {}
        if data.get("overdueNotifiedAt") is not None:
            continue
        book = data.get("bookTitle", "your book")
        if _notify_once(db, doc, data, title="Library Reminder", message=overdue_message(book),
                        push_body=f'"{book}" is overdue - please return it.',
                        notif_type="LIBRARY_OVERDUE", dedupe_field="overdueNotifiedAt"):
            count += 1
            log.info("Overdue notice sent for %r (issue %s)", book, doc.id)
    return count


def _fcm_token(db, uid: str) -> str | None:
    user_doc = db.collection("users").document(uid).get()
    return (user_doc.to_dict() or {}).get("fcmToken") if user_doc.exists else None


def notify_new_reports(db) -> int:
    """Student "I did not borrow this book" reports (issueReports). Every
    active librarian and security user is notified once per report;
    `notifiedAt` is the dedupe marker, written before the pushes."""
    reports = db.collection("issueReports").where("status", "==", "NEW").stream()
    count = 0
    for doc in reports:
        data = doc.to_dict() or {}
        if data.get("notifiedAt") is not None:
            continue
        who = f'{data.get("studentName", "A student")} ({data.get("registrationNumber", "?")})'
        book = data.get("bookTitle", "a book")
        message = f'{who} reports they did not borrow "{book}". Please check the issue records.'

        recipients: list[str] = []
        for role in ("librarian", "security"):
            for u in db.collection("users").where("role", "==", role).where("active", "==", True).stream():
                recipients.append(u.id)

        doc.reference.update({"notifiedAt": firestore.SERVER_TIMESTAMP})
        for uid in recipients:
            db.collection("notifications").add({
                "recipient": uid,
                "title": "Unauthorized Book Issue Reported",
                "message": message,
                "type": "LIBRARY_ISSUE_REPORT",
                "isRead": False,
                "metadata": {"reportId": doc.id, "issueId": data.get("issueId", "")},
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
            token = _fcm_token(db, uid)
            if token:
                try:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(title="Unauthorized Book Issue Reported", body=message),
                        token=token,
                    ))
                except Exception as exc:  # noqa: BLE001
                    log.warning("FCM send failed for %s: %s", uid, exc)
        count += 1
        log.info("Issue report %s sent to %d staff user(s)", doc.id, len(recipients))
    return count


def run_once() -> int:
    """One pass: due-soon, overdue, then new issue reports. Returns how many notices were sent
    (0 is completely normal)."""
    _init_firebase()
    db = firestore.client()
    now = dt.datetime.now(dt.timezone.utc)
    return notify_due_soon(db, now) + notify_overdue(db, now) + notify_new_reports(db)
