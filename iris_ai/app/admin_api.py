"""
Admin-only endpoints. Everything else the Admin portal needs (courses,
books, bus/stops, viewing attendance/gate entries/alerts, deactivating
accounts) is a plain Firestore read/write the Flutter app does directly,
already permitted by firebase/firestore.rules for the admin role.
"""

from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, EmailStr

from app import firebase_client, supabase_client

router = APIRouter(prefix="/admin", tags=["admin"])


def require_admin(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Missing Authorization: Bearer <Firebase ID token> header")
    token = authorization.split(" ", 1)[1]
    try:
        return firebase_client.require_admin_uid(token)
    except firebase_client.NotAuthorizedError as exc:
        raise HTTPException(403, str(exc)) from exc
    except firebase_client.FirebaseNotConfiguredError as exc:
        raise HTTPException(503, str(exc)) from exc


def require_admin_or_security(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Missing Authorization: Bearer <Firebase ID token> header")
    token = authorization.split(" ", 1)[1]
    try:
        return firebase_client.require_role_uid(token, {"admin", "security"})
    except firebase_client.NotAuthorizedError as exc:
        raise HTTPException(403, str(exc)) from exc
    except firebase_client.FirebaseNotConfiguredError as exc:
        raise HTTPException(503, str(exc)) from exc


class StudentFields(BaseModel):
    registrationNumber: str
    program: str
    semester: int = 1
    courses: list[str] = []


class CreateAccountRequest(BaseModel):
    email: EmailStr
    name: str
    role: str
    studentFields: StudentFields | None = None
    password: str | None = None


class CreateAccountResponse(BaseModel):
    uid: str
    email: str
    role: str
    temporaryPassword: str


@router.post("/accounts", response_model=CreateAccountResponse)
def create_account(body: CreateAccountRequest, authorization: str | None = Header(default=None)):
    require_admin(authorization)

    if body.role == "student" and body.studentFields is None:
        raise HTTPException(400, "studentFields is required when role='student'")

    try:
        result = firebase_client.create_account(
            email=body.email,
            name=body.name,
            role=body.role,
            student_fields=body.studentFields.model_dump() if body.studentFields else None,
            password=body.password,
        )
    except ValueError as exc:
        status = 409 if "already in use" in str(exc) else 400
        raise HTTPException(status, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(409, f"could not create account: {exc}") from exc

    return CreateAccountResponse(**result)


class DeactivateRequest(BaseModel):
    uid: str


@router.post("/accounts/deactivate")
def deactivate_account(body: DeactivateRequest, authorization: str | None = Header(default=None)):
    require_admin(authorization)
    firebase_client.deactivate_account(body.uid)
    return {"deactivated": True, "uid": body.uid}


class SignedImageUrlResponse(BaseModel):
    url: str


@router.get("/security-alert-image-url", response_model=SignedImageUrlResponse)
def get_security_alert_image_url(path: str, authorization: str | None = Header(default=None)):
    require_admin_or_security(authorization)
    try:
        url = supabase_client.create_signed_url(path)
    except supabase_client.SupabaseNotConfiguredError as exc:
        raise HTTPException(503, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(502, f"could not create signed URL: {exc}") from exc
    return SignedImageUrlResponse(url=url)


class UpdateAccountRequest(BaseModel):
    uid: str
    role: str
    name: str | None = None
    password: str | None = None


class UpdateAccountResponse(BaseModel):
    uid: str
    name: str | None
    passwordChanged: bool


@router.post("/accounts/update", response_model=UpdateAccountResponse)
def update_account(body: UpdateAccountRequest, authorization: str | None = Header(default=None)):
    require_admin(authorization)
    try:
        result = firebase_client.update_account(
            uid=body.uid, role=body.role, name=body.name, password=body.password
        )
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(409, f"could not update account: {exc}") from exc
    return UpdateAccountResponse(**result)