from __future__ import annotations

from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Absolute path to the repo-root .env - same real bug fix as
# iris_ai/app/config.py and bus_eta/app/config.py; see either for why a
# CWD-relative ".env" silently breaks depending on which directory this
# service is launched from.
_ENV_FILE = Path(__file__).resolve().parent.parent.parent / ".env"
_REPO_ROOT = _ENV_FILE.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, env_file_encoding="utf-8-sig", extra="ignore")

    FIREBASE_PROJECT_ID: str = ""
    GOOGLE_APPLICATION_CREDENTIALS: str = ""
    FIREBASE_DATABASE_URL: str = ""

    # How often to check for newly-overdue books. Short for
    # demoing/testing (e.g. 60s so you can set a due date/time a minute
    # out and watch it get picked up quickly); a real deployment would
    # widen this considerably since library due dates don't change minute
    # to minute.
    OVERDUE_CHECK_INTERVAL_SECONDS: float = 60.0

    @field_validator("GOOGLE_APPLICATION_CREDENTIALS")
    @classmethod
    def _resolve_credentials_path(cls, v: str) -> str:
        """A relative path here (e.g. "./secrets/serviceAccountKey.json",
        the value everyone actually puts in .env) is otherwise resolved
        by firebase_admin against the process's CWD when it later calls
        open() on it - the same CWD-relative bug _ENV_FILE above already
        fixes for .env itself. Resolving it against the repo root here
        (the same directory .env lives in) makes it work regardless of
        which directory this service is launched from."""
        if not v or Path(v).is_absolute():
            return v
        return str((_REPO_ROOT / v).resolve())


settings = Settings()