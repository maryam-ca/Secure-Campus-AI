from __future__ import annotations

from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Absolute path to the repo-root .env - same fix as iris_ai/app/config.py;
# see that file's comment for why a CWD-relative ".env" silently breaks
# when this service is launched with `cd bus_eta && ...` (CWD = bus_eta/).
_ENV_FILE = Path(__file__).resolve().parent.parent.parent / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, env_file_encoding="utf-8-sig", extra="ignore")

    FIREBASE_PROJECT_ID: str = ""
    GOOGLE_APPLICATION_CREDENTIALS: str = ""
    FIREBASE_DATABASE_URL: str = ""

    BUS_ID: str = "BUS-001"
    POLL_INTERVAL_SECONDS: float = 20.0
    # One alert per trip: "head to your stop" when the bus is this many minutes away.
    ALERT_THRESHOLD_MINUTES: float = 10.0
    # Assumed average bus speed. ETA = distance / this speed. The distance is the
    # real road distance (OSRM) or, if routing is off or fails, the straight line.
    AVG_BUS_SPEED_KMH: float = 25.0
    # "osrm" = free OpenStreetMap road routing (default); "straight" = straight
    # line only. A MAP_API_KEY (Google) takes priority over both.
    ROUTING_PROVIDER: str = "osrm"
    OSRM_BASE_URL: str = "https://router.project-osrm.org"
    # A driver location older than this is treated as lost (phone off, app killed,
    # no GPS): no alerts are sent from it and students are shown no live status.
    LOCATION_STALE_SECONDS: float = 180.0
    # Optional: Google Distance Matrix (or compatible) API key for a real
    # routing-based ETA instead of straight-line/haversine distance.
    MAP_API_KEY: str = ""


    @field_validator("GOOGLE_APPLICATION_CREDENTIALS")
    @classmethod
    def _resolve_credentials_path(cls, v: str) -> str:
        """.env gives this relative to the repo root (./secrets/...), but the
        service is started from bus_eta/. Resolve it against the repo root so it
        works from any directory."""
        if not v or Path(v).is_absolute():
            return v
        return str((_ENV_FILE.parent / v).resolve())


settings = Settings()