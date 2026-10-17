"""Admin-only endpoints must reject callers without a valid admin token,
and deactivation must disable the Firebase Auth user as well."""
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app import firebase_client
from app.main import app

client = TestClient(app)

PROTECTED = [
    ("post", "/admin/accounts/deactivate", {"json": {"uid": "u1"}}),
]


@pytest.mark.parametrize("method,path,kwargs", PROTECTED)
def test_missing_token_is_401(method, path, kwargs):
    assert getattr(client, method)(path, **kwargs).status_code == 401


@pytest.mark.parametrize("method,path,kwargs", PROTECTED)
def test_non_admin_token_is_403(monkeypatch, method, path, kwargs):
    def deny(token):
        raise firebase_client.NotAuthorizedError("not an admin")
    monkeypatch.setattr(firebase_client, "require_admin_uid", deny)
    resp = getattr(client, method)(path, headers={"Authorization": "Bearer x"}, **kwargs)
    assert resp.status_code == 403


def test_deactivate_disables_auth_user(monkeypatch):
    db = MagicMock()
    monkeypatch.setattr(firebase_client, "db", lambda: db)
    auth = MagicMock()
    monkeypatch.setattr(firebase_client, "fb_auth", auth)

    firebase_client.deactivate_account("u1")

    db.collection.return_value.document.return_value.update.assert_called_once_with({"active": False})
    auth.update_user.assert_called_once_with("u1", disabled=True)
    auth.revoke_refresh_tokens.assert_called_once_with("u1")
