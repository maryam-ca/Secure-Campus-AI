import datetime as dt
from unittest.mock import MagicMock

from app import service

NOW = dt.datetime(2026, 10, 13, 12, 0, tzinfo=dt.timezone.utc)


def _doc(doc_id="i1", **fields):
    d = MagicMock()
    d.id = doc_id
    d.to_dict.return_value = fields
    return d


def _db(docs, token=None):
    """Fake Firestore: any .where(...).stream() chain yields `docs`."""
    db = MagicMock()
    chain = db.collection.return_value
    for _ in range(3):
        chain.where.return_value = chain
    chain.stream.return_value = iter(docs)
    user = MagicMock(exists=token is not None)
    user.to_dict.return_value = {"fcmToken": token}
    chain.document.return_value.get.return_value = user
    return db


def test_due_soon_message_hours():
    msg = service.due_soon_message("Algorithms", NOW + dt.timedelta(hours=30, minutes=10), NOW)
    assert "Algorithms" in msg and "about 30 hours" in msg


def test_due_soon_message_under_an_hour():
    assert "less than an hour" in service.due_soon_message("X", NOW + dt.timedelta(minutes=20), NOW)


def test_overdue_message_mentions_informational_fine():
    assert "informational only" in service.overdue_message("Algorithms")


def test_due_soon_notifies_once_and_marks_issue():
    doc = _doc(studentId="s1", bookTitle="Algorithms", bookId="B1", expiryDate=NOW + dt.timedelta(hours=10))
    db = _db([doc])
    assert service.notify_due_soon(db, NOW) == 1
    added = db.collection.return_value.add.call_args[0][0]
    assert added["type"] == "LIBRARY_DUE_SOON" and added["recipient"] == "s1"
    assert "dueSoonNotifiedAt" in doc.reference.update.call_args[0][0]


def test_due_soon_skips_already_notified():
    doc = _doc(studentId="s1", dueSoonNotifiedAt=NOW, expiryDate=NOW + dt.timedelta(hours=10))
    db = _db([doc])
    assert service.notify_due_soon(db, NOW) == 0
    db.collection.return_value.add.assert_not_called()


def test_overdue_notifies_once_and_skips_already_notified():
    fresh = _doc("a", studentId="s1", bookTitle="A", expiryDate=NOW - dt.timedelta(days=1))
    done = _doc("b", studentId="s2", bookTitle="B", overdueNotifiedAt=NOW)
    db = _db([fresh, done])
    assert service.notify_overdue(db, NOW) == 1
    assert db.collection.return_value.add.call_args[0][0]["type"] == "LIBRARY_OVERDUE"


def test_issue_without_student_is_skipped():
    doc = _doc(bookTitle="A", expiryDate=NOW - dt.timedelta(days=1))
    assert service.notify_overdue(_db([doc]), NOW) == 0


def test_push_failure_does_not_unmark_or_raise(monkeypatch):
    monkeypatch.setattr(service.messaging, "send", MagicMock(side_effect=RuntimeError("fcm down")))
    doc = _doc(studentId="s1", bookTitle="A", expiryDate=NOW - dt.timedelta(days=1))
    assert service.notify_overdue(_db([doc], token="tok"), NOW) == 1
    doc.reference.update.assert_called_once()


def _reports_db(report, users_by_role):
    """Fake db where issueReports yields `report` and users query yields per-role lists."""
    db = MagicMock()
    reports_q = MagicMock()
    reports_q.where.return_value.stream.return_value = iter([report])

    def users_where(field, op, value):
        q = MagicMock()
        q.where.return_value.stream.return_value = iter(users_by_role.get(value, []))
        return q

    users_q = MagicMock()
    users_q.where.side_effect = users_where
    users_q.document.return_value.get.return_value = MagicMock(exists=False)
    notifications = MagicMock()

    def collection(name):
        return {"issueReports": reports_q, "users": users_q, "notifications": notifications}[name]

    db.collection.side_effect = collection
    return db, notifications


def _user(uid):
    u = MagicMock()
    u.id = uid
    return u


def test_new_report_notifies_librarian_and_security_once():
    report = _doc("r1", studentName="Ayesha", registrationNumber="FA23-BSE-001",
                  bookTitle="Algorithms", issueId="i1", status="NEW")
    db, notifications = _reports_db(report, {"librarian": [_user("lib1")], "security": [_user("sec1"), _user("sec2")]})

    assert service.notify_new_reports(db) == 1

    recipients = [c[0][0]["recipient"] for c in notifications.add.call_args_list]
    assert recipients == ["lib1", "sec1", "sec2"]
    assert notifications.add.call_args_list[0][0][0]["type"] == "LIBRARY_ISSUE_REPORT"
    assert "notifiedAt" in report.reference.update.call_args[0][0]


def test_already_notified_report_is_skipped():
    report = _doc("r1", studentName="A", bookTitle="B", status="NEW", notifiedAt=NOW)
    db, notifications = _reports_db(report, {"librarian": [_user("lib1")]})
    assert service.notify_new_reports(db) == 0
    notifications.add.assert_not_called()
