"""
SecureCampus Bus ETA job. Runs standalone:

    python -m app.main

or via Docker (see ../Dockerfile / ../docker-compose.yml). Polls the
single campus bus's live location every POLL_INTERVAL_SECONDS and sends
the ~10-minute-away notification to each affected student, once per
trip (see app/service.py for the dedup logic).
"""

from __future__ import annotations

import logging
import time

from app.config import settings
from app.service import run_once

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("bus_eta.main")


def main() -> None:
    log.info("bus_eta starting - bus_id=%s poll_interval=%ss first=%smin final=%smin",
              settings.BUS_ID, settings.POLL_INTERVAL_SECONDS, settings.ALERT_FIRST_MINUTES, settings.ALERT_THRESHOLD_MINUTES)
    while True:
        try:
            run_once()
        except Exception:
            log.exception("bus_eta cycle failed - will retry next interval")
        time.sleep(settings.POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
