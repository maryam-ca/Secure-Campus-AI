"""create_unknown_alert: photo goes to Firebase Storage; a failed upload must
not stop the alert itself (Security still gets notified, just without a photo)."""
from unittest.mock import MagicMock

from app import firebase_client


def _fake_db():
    db = MagicMock()
    # cooldown query returns no recent alert
    db.collection.return_value.where.return_value.where.return_value.limit.return_value.stream.return_value = iter([])
    return db


def _patch(monkeypatch, bucket):
    db = _fake_db()
    monkeypatch.setattr(firebase_client, "db", lambda: db)
    monkeypatch.setattr(firebase_client, "init_firebase", lambda: None)
    monkeypatch.setattr(firebase_client.fb_storage, "bucket", lambda: bucket)
    notify = MagicMock()
    monkeypatch.setattr(firebase_client, "notify_role", notify)
    return db, notify


def test_alert_stores_firebase_storage_path(monkeypatch):
    bucket = MagicMock()
    db, notify = _patch(monkeypatch, bucket)

    created, _ = firebase_client.create_unknown_alert(b"jpeg", "GATE-CAM", "Main Gate", 0.1)

    assert created
    path = bucket.blob.call_args[0][0]
    assert path.startswith("security_alerts/GATE-CAM/") and path.endswith(".jpg")
    saved = db.collection.return_value.add.call_args[0][0]
    assert saved["imagePath"] == path
    notify.assert_called_once()


def test_alert_still_created_when_upload_fails(monkeypatch):
    bucket = MagicMock()
    bucket.blob.return_value.upload_from_string.side_effect = RuntimeError("bucket missing")
    db, notify = _patch(monkeypatch, bucket)

    created, _ = firebase_client.create_unknown_alert(b"jpeg", "GATE-CAM", "Main Gate", 0.1)

    assert created
    assert db.collection.return_value.add.call_args[0][0]["imagePath"] == ""
    notify.assert_called_once()
