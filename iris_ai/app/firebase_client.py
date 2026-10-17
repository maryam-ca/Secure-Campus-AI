"""
Firebase access for the backend service (Phase 1): Firebase Admin SDK setup and
Admin-only account management (create, update, deactivate). The iris recognition
reads and writes (templates, attendance, gate entries, unknown-person alerts)
are Phase 2 and live on the `phase-2` branch.

This module requires a real Firebase project and a real service-account key
(GOOGLE_APPLICATION_CREDENTIALS): there is no offline or mocked fallback, by
design. Initialization is lazy, so importing it never requires credentials;
only calling into it does.
"""

from __future__ import annotations

import logging
import secrets
from typing import Any

import firebase_admin
from firebase_admin import auth as fb_auth
from firebase_admin import credentials, db as rtdb, firestore

from app.config import settings

log = logging.getLogger("securecampus.iris_ai.firebase")

_app: firebase_admin.App | None = None


class FirebaseNotConfiguredError(RuntimeError):
    pass


def init_firebase() -> firebase_admin.App:
    global _app
    if _app is not None:
        return _app

    if not settings.GOOGLE_APPLICATION_CREDENTIALS:
        raise FirebaseNotConfiguredError(
            "GOOGLE_APPLICATION_CREDENTIALS is not set. Point it at your Firebase "
            "service-account JSON (see .env.example / README Firebase setup)."
        )

    cred = credentials.Certificate(settings.GOOGLE_APPLICATION_CREDENTIALS)
    _app = firebase_admin.initialize_app(cred, {
        "storageBucket": settings.FIREBASE_STORAGE_BUCKET or None,
        "projectId": settings.FIREBASE_PROJECT_ID or None,
        "databaseURL": settings.FIREBASE_DATABASE_URL or None,
    })
    return _app


def db() -> firestore.Client:
    init_firebase()
    return firestore.client()


# --------------------------------------------------------------------------
# Admin-only account management
# --------------------------------------------------------------------------

class NotAuthorizedError(RuntimeError):
    pass


def require_role_uid(id_token: str, allowed_roles: set[str]) -> str:
    init_firebase()
    try:
        decoded = fb_auth.verify_id_token(id_token)
    except Exception as exc:
        raise NotAuthorizedError(f"invalid or expired ID token: {exc}") from exc

    uid = decoded["uid"]
    user_doc = db().collection("users").document(uid).get()
    data = user_doc.to_dict() if user_doc.exists else None
    if not data or data.get("role") not in allowed_roles or not data.get("active", False):
        raise NotAuthorizedError(f"caller does not have one of the required roles: {sorted(allowed_roles)}")
    return uid


def require_admin_uid(id_token: str) -> str:
    return require_role_uid(id_token, {"admin"})


def create_account(email: str, name: str, role: str,
                    student_fields: dict[str, Any] | None = None,
                    password: str | None = None) -> dict[str, Any]:
    if role not in ("admin", "student", "security", "librarian", "driver"):
        raise ValueError(f"invalid role: {role}")

    reg_no = None
    if role == "student":
        fields = student_fields or {}
        reg_no = (fields.get("registrationNumber") or "").strip()
        if not reg_no:
            raise ValueError("registrationNumber is required for role='student'")
        _reserve_registration_number(reg_no)

    # Never default to something guessable (it used to be the registration number).
    # Every account gets a random temporary password unless the caller supplies one;
    # the account is flagged mustResetPassword so the user has to replace it at first login.
    chosen_password = password or secrets.token_urlsafe(9)
    if len(chosen_password) < 6:
        if reg_no:
            db().collection("registrationNumbers").document(reg_no).delete()
        raise ValueError("password must be at least 6 characters (Firebase Auth requirement)")

    try:
        user_record = fb_auth.create_user(email=email, password=chosen_password, display_name=name)
    except Exception:
        if reg_no:
            db().collection("registrationNumbers").document(reg_no).delete()
        raise

    uid = user_record.uid

    db().collection("users").document(uid).set({
        "uid": uid, "email": email, "name": name, "role": role,
        "active": True, "createdAt": firestore.SERVER_TIMESTAMP,
        "mustResetPassword": True,
    })

    if settings.FIREBASE_DATABASE_URL:
        rtdb.reference(f"roles/{uid}").set(role)

    if role == "student":
        fields = student_fields or {}
        db().collection("students").document(uid).set({
            "uid": uid,
            "registrationNumber": reg_no,
            "name": name,
            "program": fields.get("program", ""),
            "semester": fields.get("semester", 1),
            "email": email,
            "courses": fields.get("courses", []),
            "irisEnrolled": False,
        })
        db().collection("registrationNumbers").document(reg_no).set(
            {"studentUid": uid, "reservedAt": firestore.SERVER_TIMESTAMP}, merge=True
        )

    return {"uid": uid, "email": email, "role": role, "temporaryPassword": chosen_password}


def _reserve_registration_number(reg_no: str) -> None:
    doc_ref = db().collection("registrationNumbers").document(reg_no)

    @firestore.transactional
    def _reserve(transaction: firestore.Transaction) -> None:
        snapshot = doc_ref.get(transaction=transaction)
        if snapshot.exists:
            raise ValueError(f"registration number '{reg_no}' is already in use")
        transaction.set(doc_ref, {"status": "pending", "reservedAt": firestore.SERVER_TIMESTAMP})

    _reserve(db().transaction())


def deactivate_account(uid: str) -> None:
    """Marks the profile inactive (rules/router/backend all check this) AND
    disables the Firebase Auth user and revokes its refresh tokens, so the
    person can no longer sign in or keep using an existing session."""
    db().collection("users").document(uid).update({"active": False})
    fb_auth.update_user(uid, disabled=True)
    fb_auth.revoke_refresh_tokens(uid)


def update_account(uid: str, role: str, name: str | None = None, password: str | None = None) -> dict[str, Any]:
    """Lets Admin change an existing account's display name and/or reset
    its password after creation - previously the only account-management
    actions were create/deactivate."""
    if name is None and password is None:
        raise ValueError("provide at least one of name or password to update")
    if password is not None and len(password) < 6:
        raise ValueError("password must be at least 6 characters (Firebase Auth requirement)")

    auth_kwargs: dict[str, Any] = {}
    if name is not None:
        auth_kwargs["display_name"] = name
    if password is not None:
        auth_kwargs["password"] = password
    fb_auth.update_user(uid, **auth_kwargs)

    if name is not None:
        db().collection("users").document(uid).update({"name": name})
        if role == "student":
            db().collection("students").document(uid).update({"name": name})

    if password is not None:
        db().collection("users").document(uid).update({"mustResetPassword": True})

    return {"uid": uid, "name": name, "passwordChanged": password is not None}