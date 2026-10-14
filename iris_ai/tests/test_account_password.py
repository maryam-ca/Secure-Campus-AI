"""A new account must never get a guessable password (it used to be the student's
registration number) and must be flagged to change it at first login."""
from unittest.mock import MagicMock

from app import firebase_client


def _patch(monkeypatch):
    db = MagicMock()
    monkeypatch.setattr(firebase_client, "db", lambda: db)
    monkeypatch.setattr(firebase_client, "_reserve_registration_number", lambda reg: None)
    auth = MagicMock()
    auth.create_user.return_value = MagicMock(uid="uid-1")
    monkeypatch.setattr(firebase_client, "fb_auth", auth)
    monkeypatch.setattr(firebase_client, "rtdb", MagicMock())
    return db, auth


def test_student_gets_a_random_password_not_the_registration_number(monkeypatch):
    db, auth = _patch(monkeypatch)

    result = firebase_client.create_account(
        email="s@x.edu", name="Student", role="student",
        student_fields={"registrationNumber": "FA23-BSE-077", "program": "BSE"},
    )

    password = auth.create_user.call_args.kwargs["password"]
    assert password == result["temporaryPassword"]
    assert password != "FA23-BSE-077"
    assert "FA23" not in password and len(password) >= 8


def test_two_accounts_get_different_passwords(monkeypatch):
    _patch(monkeypatch)
    a = firebase_client.create_account(email="a@x.edu", name="A", role="librarian")
    b = firebase_client.create_account(email="b@x.edu", name="B", role="librarian")
    assert a["temporaryPassword"] != b["temporaryPassword"]


def test_account_is_flagged_to_change_password_at_first_login(monkeypatch):
    db, _ = _patch(monkeypatch)
    firebase_client.create_account(email="s@x.edu", name="S", role="student",
                                   student_fields={"registrationNumber": "FA23-BSE-078"})
    user_doc = [c for c in db.collection.return_value.document.return_value.set.call_args_list
                if c[0] and c[0][0].get("role") == "student"][0][0][0]
    assert user_doc["mustResetPassword"] is True


def test_an_explicit_password_is_still_respected_but_must_be_long_enough(monkeypatch):
    _, auth = _patch(monkeypatch)
    firebase_client.create_account(email="s@x.edu", name="S", role="driver", password="a-good-pass1")
    assert auth.create_user.call_args.kwargs["password"] == "a-good-pass1"

    import pytest
    with pytest.raises(ValueError):
        firebase_client.create_account(email="t@x.edu", name="T", role="driver", password="123")
