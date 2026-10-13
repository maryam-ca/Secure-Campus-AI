"""
SecureCampus overdue-book checker. Runs standalone:

    python -m app.main
"""

from __future__ import annotations

import logging
import time

from app.config import settings
from app.service import run_once

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("overdue_checker.main")


def main() -> None:
    log.info("overdue_checker starting - poll_interval=%ss", settings.OVERDUE_CHECK_INTERVAL_SECONDS)
    while True:
        try:
            count = run_once()
            if count:
                log.info("Notified %d student(s) this pass", count)
        except Exception:
            log.exception("overdue check pass failed - will retry next interval")
        time.sleep(settings.OVERDUE_CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()