from __future__ import annotations

from pathlib import Path

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
    # Used only as a fallback ETA estimate when MAP_API_KEY is not set -
    # a real routing API call (below) is preferred when available.
    AVG_BUS_SPEED_KMH: float = 25.0
    # A driver location older than this is treated as lost (phone off, app killed,
    # no GPS): no alerts are sent from it and students are shown no live status.
    LOCATION_STALE_SECONDS: float = 180.0
    # Optional: Google Distance Matrix (or compatible) API key for a real
    # routing-based ETA instead of straight-line/haversine distance.
    MAP_API_KEY: str = ""


settings = Settings()