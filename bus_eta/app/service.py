"""
One polling cycle of the bus ETA job: read the driver's live location,
and for every student assigned to this bus with a registered stop,
compute ETA and send up to TWO in-app reminders per trip:

  1. "Get ready"  - when the bus is about ALERT_FIRST_MINUTES (20) away.
  2. "Head to your stop" - when it is about ALERT_THRESHOLD_MINUTES (10) away.

Each stage is sent at most once per student per trip (dedupe fields
`alertFirstTripId` / `alertFinalTripId` on the busAssignments doc; the
legacy `lastAlertTripId` is still honoured as "final already sent").
If the first reading for a student is already inside the 10-minute window
(e.g. the driver started the trip late), only the final alert is sent -
a "get ready" notice that late would be noise.
"""

from __future__ import annotations

import logging

from app import firebase_client
from app.config import settings
from app.geo import estimate_eta_minutes

log = logging.getLogger("bus_eta")

FIRST = "first"
FINAL = "final"


def decide_alert(eta_minutes: float, first_sent: bool, final_sent: bool,
                 first_threshold: float, final_threshold: float) -> str | None:
    """Which alert (if any) to send now. Pure function so it can be unit
    tested without Firebase."""
    if final_sent:
        return None
    if eta_minutes <= final_threshold:
        return FINAL
    if eta_minutes <= first_threshold and not first_sent:
        return FIRST
    return None


def run_once() -> int:
    """Returns the number of notifications sent this cycle (mostly useful
    for tests/logging - the real side effects are the Firestore writes)."""
    location = firebase_client.read_driver_location(settings.BUS_ID)

    if location is None or not location.trip_active:
        log.info("bus %s: no active trip - nothing to do", settings.BUS_ID)
        return 0

    if location.trip_id is None:
        log.warning("bus %s: trip active but no tripId set - cannot dedupe alerts, skipping", settings.BUS_ID)
        return 0

    assignments = firebase_client.fetch_active_assignments_with_stops(settings.BUS_ID)
    sent = 0

    for assignment in assignments:
        student_id = assignment.get("studentId")
        if not student_id:
            continue

        trip = location.trip_id
        final_sent = trip in (assignment.get("alertFinalTripId"), assignment.get("lastAlertTripId"))
        first_sent = assignment.get("alertFirstTripId") == trip
        if final_sent:
            continue

        eta_minutes, method = estimate_eta_minutes(
            origin=(location.lat, location.lng),
            dest=(assignment["stopLat"], assignment["stopLng"]),
            avg_speed_kmh=settings.AVG_BUS_SPEED_KMH,
            api_key=settings.MAP_API_KEY,
        )

        stage = decide_alert(eta_minutes, first_sent, final_sent,
                             settings.ALERT_FIRST_MINUTES, settings.ALERT_THRESHOLD_MINUTES)
        if stage is None:
            continue

        firebase_client.notify_student_bus(student_id, assignment["stopName"], eta_minutes, stage)
        firebase_client.mark_alert_sent(assignment["id"], trip, stage)
        sent += 1
        log.info("bus %s: %s alert to student %s (%.1f min via %s) for stop %s",
                 settings.BUS_ID, stage, student_id, eta_minutes, method, assignment["stopName"])

    return sent
