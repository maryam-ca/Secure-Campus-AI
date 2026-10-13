"""
Central configuration for the iris AI service. Everything that varies
between environments (camera source, recognition threshold, Firebase
project, credential path) is read from environment variables so nothing
environment-specific is hardcoded in code. See ../.env.example.
"""

from __future__ import annotations

from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Absolute path to the repo-root .env (iris_ai/app/config.py -> iris_ai/app
# -> iris_ai -> repo root), NOT a CWD-relative ".env" - fixed after a real
# bug: when this service is launched with `cd iris_ai && uvicorn ...`
# (CWD = iris_ai/), a relative ".env" looked for iris_ai/.env, which
# doesn't exist, and every setting silently fell back to its default
# (e.g. CAMERA_RTSP_URL="") with no error - just a service that quietly
# didn't work. seed_firebase.py and backfill_rtdb_roles.py happened to
# work because they're run from the repo root, where ".env" and the
# real file coincide; this makes it work the same way regardless of
# which directory the command is run from.
_ENV_FILE = Path(__file__).resolve().parent.parent.parent / ".env"
_REPO_ROOT = _ENV_FILE.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, env_file_encoding="utf-8-sig", extra="ignore")

    # Firebase
    FIREBASE_PROJECT_ID: str = ""
    GOOGLE_APPLICATION_CREDENTIALS: str = ""  # path to service account JSON
    FIREBASE_STORAGE_BUCKET: str = ""
    FIREBASE_DATABASE_URL: str = ""  # Realtime Database URL, needed for driver GPS reads

    # Camera
    CAMERA_RTSP_URL: str = ""
    CAMERA_NAME: str = "MAIN-CAM"
    CAMERA_LOCATION: str = "unassigned"

    # Iris recognition
    IRIS_MATCH_THRESHOLD: float = 0.32  # NOT experimentally validated - see docs/IRIS_MODEL.md
    IRIS_MODEL_PATH: str = ""  # reserved: path to a future deep-embedding model, unused by the classical pipeline

    # Event handling
    UNKNOWN_ALERT_COOLDOWN_SECONDS: int = 120   # per-camera cooldown between UNKNOWN alerts
    ATTENDANCE_DEDUPE_MINUTES: int = 30         # don't re-mark attendance for same student+course within this window
    RECOGNITION_INTERVAL_SECONDS: float = 2.0   # how often the live loop pulls & processes a frame

    # Service
    API_PORT: int = 8000

    @field_validator("GOOGLE_APPLICATION_CREDENTIALS")
    @classmethod
    def _resolve_credentials_path(cls, v: str) -> str:
        """A relative path here (e.g. "./secrets/serviceAccountKey.json",
        the value everyone actually puts in .env) is otherwise resolved
        by firebase_admin against the process's CWD when it later calls
        open() on it - a second instance of the exact same CWD-relative
        bug _ENV_FILE above already fixes for .env itself. Resolving it
        against the repo root here (the same directory .env lives in)
        makes it work regardless of which directory the service is
        launched from."""
        if not v or Path(v).is_absolute():
            return v
        return str((_REPO_ROOT / v).resolve())


settings = Settings()