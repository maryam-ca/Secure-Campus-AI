"""
All Firebase access for the iris AI service lives here: Firestore reads
of enrolled iris templates and active course schedules, Firestore writes
of attendance/gate-entry/security-alert/notification records, Storage
uploads of captured unknown-person frames, and FCM push sends.

This module requires a real Firebase project and a real service-account
key (GOOGLE_APPLICATION_CREDENTIALS) to function - there is no offline
or mocked fallback, by design: the project spec explicitly forbids fake
Firebase data. Initialization is lazy so importing this module (e.g. for
unit tests of the pure recognition code) never requires credentials to
be present; only calling into it does.
"""

from __future__ import annotations

import datetime as dt
import logging
import secrets
import time
from typing import Any

import firebase_admin
from firebase_admin import auth as fb_auth
from firebase_admin import credentials, db as rtdb, firestore, messaging, storage as fb_storage

from app.config import settings
from app.recognition.encoding import IrisTemplate

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
# Iris profiles (irisProfiles/{studentId})
# --------------------------------------------------------------------------

def save_iris_profile(student_id: str, template: IrisTemplate, algorithm_version: str = "daugman-loggabor-v1") -> None:
    code_bytes, mask_bytes, shape = template.to_bytes()
    db().collection("irisProfiles").document(student_id).set({
        "studentId": student_id,
        "code": code_bytes,
        "mask": mask_bytes,
        "shape": list(shape),
        "algorithmVersion": algorithm_version,
        "enrolledAt": firestore.SERVER_TIMESTAMP,
    })
    db().collection("students").document(student_id).set(
        {"irisEnrolled": True}, merge=True
    )


def load_enrolled_templates() -> dict[str, IrisTemplate]:
    """Loads every enrolled iris template. Called by the recognition loop
    at a low frequency (not per-frame) and cached by the caller."""
    out: dict[str, IrisTemplate] = {}
    for doc in db().collection("irisProfiles").stream():
        data = doc.to_dict()
        try:
            shape = tuple(data["shape"])
            template = IrisTemplate.from_bytes(data["code"], data["mask"], shape)
            out[doc.id] = template
        except (KeyError, ValueError):
            continue
    return out


# --------------------------------------------------------------------------
# Course scheduling (courses/{courseId})
# --------------------------------------------------------------------------

def find_active_course_for_camera(camera_id: str, now: dt.datetime | None = None) -> dict[str, Any] | None:
    now = now or dt.datetime.now()
    day_name = now.strftime("%A")
    current_time = now.strftime("%H:%M")

    query = db().collection("courses").where("cameraId", "==", camera_id).stream()
    for doc in query:
        course = doc.to_dict()
        course["id"] = doc.id
        for slot in course.get("schedule", []):
            if slot.get("dayOfWeek") != day_name:
                continue
            if slot.get("startTime", "00:00") <= current_time <= slot.get("endTime", "00:00"):
                return course
    return None


# --------------------------------------------------------------------------
# Attendance (attendance/{autoId}) - with duplicate prevention
# --------------------------------------------------------------------------

def _ensure_class_session(course_id: str, date_str: str, camera_id: str) -> None:
    session_id = f"{course_id}_{date_str}"
    doc_ref = db().collection("classSessions").document(session_id)
    doc_ref.set({
        "courseId": course_id,
        "date": date_str,
        "cameraId": camera_id,
        "createdAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)


def record_attendance(student_id: str, registration_number: str, course_id: str,
                       camera_id: str, camera_location: str, score: float) -> tuple[bool, str]:
    today_str = dt.date.today().isoformat()
    _ensure_class_session(course_id, today_str, camera_id)

    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=settings.ATTENDANCE_DEDUPE_MINUTES)
    existing = (
        db().collection("attendance")
        .where("studentId", "==", student_id)
        .where("courseId", "==", course_id)
        .where("createdAt", ">=", cutoff)
        .limit(1)
        .stream()
    )
    if next(existing, None) is not None:
        return False, "duplicate attendance suppressed (already marked recently for this course)"

    db().collection("attendance").add({
        "studentId": student_id,
        "registrationNumber": registration_number,
        "courseId": course_id,
        "date": today_str,
        "time": dt.datetime.now().strftime("%H:%M:%S"),
        "recognitionScore": score,
        "recognitionStatus": "VERIFIED",
        "cameraId": camera_id,
        "cameraLocation": camera_location,
        "createdAt": firestore.SERVER_TIMESTAMP,
    })
    return True, "attendance recorded"


# --------------------------------------------------------------------------
# Gate entries (gateEntries/{autoId}) - entry only, visible to Admin/Security
# --------------------------------------------------------------------------

def record_gate_entry(student_id: str, registration_number: str, name: str,
                       camera_id: str, camera_location: str, score: float) -> str:
    doc_ref = db().collection("gateEntries").add({
        "studentId": student_id,
        "registrationNumber": registration_number,
        "name": name,
        "status": "VERIFIED_ENTRY",
        "recognitionScore": score,
        "cameraId": camera_id,
        "cameraLocation": camera_location,
        "timestamp": firestore.SERVER_TIMESTAMP,
    })
    return doc_ref[1].id


# --------------------------------------------------------------------------
# Unknown-person security alerts - with cooldown/dedup and image capture
# --------------------------------------------------------------------------

def create_unknown_alert(image_bytes: bytes, camera_id: str, camera_location: str,
                          best_score: float) -> tuple[bool, str]:
    """Image storage: uploaded to Firebase Storage under
    security_alerts/{cameraId}/{timestamp}.jpg (private - storage.rules
    allow reads only for signed-in Admin/Security). Only the path is stored
    in Firestore; the Flutter client resolves a viewing URL with
    getDownloadURL(), which storage.rules checks on every call. If the
    upload fails (e.g. Storage not enabled for the project) the alert is
    still created, just without a photo, so Security is never left blind."""
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=settings.UNKNOWN_ALERT_COOLDOWN_SECONDS)
    recent = (
        db().collection("securityAlerts")
        .where("cameraId", "==", camera_id)
        .where("createdAt", ">=", cutoff)
        .limit(1)
        .stream()
    )
    if next(recent, None) is not None:
        return False, "unknown-person alert suppressed by cooldown"

    ts = int(time.time())
    blob_path = f"security_alerts/{camera_id}/{ts}.jpg"
    try:
        init_firebase()
        fb_storage.bucket().blob(blob_path).upload_from_string(image_bytes, content_type="image/jpeg")
    except Exception as exc:  # noqa: BLE001 - never lose the alert because of the photo
        log.warning("could not upload alert image to Firebase Storage: %s", exc)
        blob_path = ""

    db().collection("securityAlerts").add({
        "type": "UNKNOWN_PERSON",
        "cameraId": camera_id,
        "cameraLocation": camera_location,
        "imagePath": blob_path,
        "bestMatchScore": best_score,
        "status": "NEW",
        "createdAt": firestore.SERVER_TIMESTAMP,
    })

    notify_role("security", "Unknown Person Detected",
                f"An unrecognized person was detected at {camera_location}.",
                "UNKNOWN_PERSON", metadata={"cameraId": camera_id})
    return True, "unknown-person alert created"


# --------------------------------------------------------------------------
# Notifications (notifications/{autoId} + FCM)
# --------------------------------------------------------------------------

def notify_user(uid: str, title: str, message: str, notif_type: str,
                 metadata: dict[str, Any] | None = None) -> None:
    db().collection("notifications").add({
        "recipient": uid,
        "title": title,
        "message": message,
        "type": notif_type,
        "isRead": False,
        "metadata": metadata or {},
        "createdAt": firestore.SERVER_TIMESTAMP,
    })

    user_doc = db().collection("users").document(uid).get()
    token = (user_doc.to_dict() or {}).get("fcmToken") if user_doc.exists else None
    if token:
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(title=title, body=message),
                token=token,
                data={k: str(v) for k, v in (metadata or {}).items()},
            ))
        except Exception:
            pass


def notify_role(role: str, title: str, message: str, notif_type: str,
                 metadata: dict[str, Any] | None = None) -> None:
    users = db().collection("users").where("role", "==", role).where("active", "==", True).stream()
    for u in users:
        notify_user(u.id, title, message, notif_type, metadata)


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