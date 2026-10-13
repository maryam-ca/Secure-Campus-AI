"""
One polling cycle of the bus ETA job: read the driver's live location,
and for every student assigned to this bus with a registered stop,
compute ETA and fire the "~10 minutes away" notification exactly once
per trip (spec §35 - never spammed, never sent to the wrong student).
"""

from __future__ import annotations

import logging

from app import firebase_client
from app.config import settings
from app.geo import estimate_eta_minutes

log = logging.getLogger("bus_eta")


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

        if assignment.get("lastAlertTripId") == location.trip_id:
            continue  # already alerted this student for this trip

        eta_minutes, method = estimate_eta_minutes(
            origin=(location.lat, location.lng),
            dest=(assignment["stopLat"], assignment["stopLng"]),
            avg_speed_kmh=settings.AVG_BUS_SPEED_KMH,
            api_key=settings.MAP_API_KEY,
        )

        if eta_minutes <= settings.ALERT_THRESHOLD_MINUTES:
            firebase_client.notify_student_bus_arriving(student_id, assignment["stopName"], eta_minutes)
            firebase_client.mark_alert_sent(assignment["id"], location.trip_id)
            sent += 1
            log.info("bus %s: notified student %s (%.1f min via %s) for stop %s",
                      settings.BUS_ID, student_id, eta_minutes, method, assignment["stopName"])

    return sent
