"""A student's Program must match the program inside the registration number,
and deleting a student removes everything except history."""
from unittest.mock import MagicMock

import pytest

from app import firebase_client
from app.registration import program_in_registration_number, program_mismatch


def test_program_is_read_from_the_number():
    assert program_in_registration_number("FA23-BSE-011") == "BSE"
    assert program_in_registration_number("fa23bsi011") == "BSI"
    assert program_in_registration_number("FA23 BCS 7") == "BCS"
    assert program_in_registration_number("LIB/2024/7") is None


def test_same_program_is_fine_whatever_the_case_or_spacing():
    assert program_mismatch("FA23-BSE-011", "BSE") is None
    assert program_mismatch("fa23-bse-011", " bse ") is None


def test_different_program_is_refused_with_a_clear_sentence():
    msg = program_mismatch("FA23-BSI-011", "BSE")
    assert "BSI" in msg and "BSE" in msg


def test_unknown_formats_and_empty_program_are_not_checked():
    assert program_mismatch("LIB/2024/7", "BSE") is None
    assert program_mismatch("FA23-BSE-011", "") is None


def test_create_account_refuses_a_mismatch_before_reserving_anything(monkeypatch):
    reserve = MagicMock()
    monkeypatch.setattr(firebase_client, "_reserve_registration_number", reserve)
    with pytest.raises(ValueError, match="BSI"):
        firebase_client.create_account(
            "a@b.pk", "A", "student", student_fields={"registrationNumber": "FA23-BSI-011", "program": "BSE"}
        )
    reserve.assert_not_called()


def _fake_db(role="student", open_loans=0, reg="FA23-BSE-011"):
    docs = {}

    def collection(name):
        col = MagicMock()

        def document(doc_id):
            d = docs.setdefault((name, doc_id), MagicMock())
            if name == "users":
                d.get.return_value = MagicMock(exists=True, to_dict=lambda: {"role": role})
            if name == "students":
                d.get.return_value = MagicMock(exists=True, to_dict=lambda: {"registrationNumber": reg})
            return d

        col.document.side_effect = document
        col.where.return_value.where.return_value.stream.return_value = [object()] * open_loans
        return col

    db = MagicMock()
    db.collection.side_effect = collection
    return db, docs


def test_delete_student_removes_login_profile_and_frees_the_number(monkeypatch):
    db, docs = _fake_db()
    auth = MagicMock()
    monkeypatch.setattr(firebase_client, "db", lambda: db)
    monkeypatch.setattr(firebase_client, "fb_auth", auth)
    monkeypatch.setattr(firebase_client.settings, "FIREBASE_DATABASE_URL", "", raising=False)

    result = firebase_client.delete_student("u1")

    auth.delete_user.assert_called_once_with("u1")
    for key in [("users", "u1"), ("students", "u1"), ("busAssignments", "u1"), ("registrationNumbers", "FA23-BSE-011")]:
        docs[key].delete.assert_called_once()
    assert result["registrationNumber"] == "FA23-BSE-011"


def test_delete_student_is_refused_while_a_book_is_out(monkeypatch):
    db, docs = _fake_db(open_loans=2)
    auth = MagicMock()
    monkeypatch.setattr(firebase_client, "db", lambda: db)
    monkeypatch.setattr(firebase_client, "fb_auth", auth)
    with pytest.raises(ValueError, match="2 book"):
        firebase_client.delete_student("u1")
    auth.delete_user.assert_not_called()


def test_delete_student_refuses_a_non_student(monkeypatch):
    db, _ = _fake_db(role="librarian")
    auth = MagicMock()
    monkeypatch.setattr(firebase_client, "db", lambda: db)
    monkeypatch.setattr(firebase_client, "fb_auth", auth)
    with pytest.raises(ValueError, match="not a student"):
        firebase_client.delete_student("u1")
    auth.delete_user.assert_not_called()
