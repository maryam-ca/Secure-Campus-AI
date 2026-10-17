"""
One polling cycle of the bus ETA job: read the driver's live location,
and for every student assigned to this bus with a registered stop,
compute ETA and send ONE in-app alert per trip: "Head to your stop", when the
bus is about ALERT_THRESHOLD_MINUTES (10) away.

It is sent at most once per student per trip (dedupe field `alertFinalTripId`
on the busAssignments doc; the legacy `lastAlertTripId` is still honoured).
If the first reading for a student is already inside the 10-minute window
(e.g. the driver started the trip late), the alert is sent at once.
"""

from __future__ import annotations

import datetime as dt
import logging
import time

from app import firebase_client
from app.config import settings
from app.geo import estimate_eta_minutes

log = logging.getLogger("bus_eta")

FINAL = "final"

# Firestore's free tier allows 20,000 writes a day, so a status is written only
# when it has changed, and otherwise at most once every REFRESH_SECONDS to keep
# it "fresh" (the student app treats a status older than 3 minutes as stale).
REFRESH_SECONDS = 120


def should_write_status(stored_active, stored_eta, stored_updated_at, new_eta: int, now) -> bool:
    """Whether to write the trip status for one student this cycle. Pure so it can be tested."""
    if stored_active is not True or stored_eta is None or stored_updated_at is None:
        return True
    if stored_eta != new_eta:
        return True
    return (now - stored_updated_at).total_seconds() >= REFRESH_SECONDS


_trip_was_active = False  # to clear the statuses once when a trip ends


def is_stale(updated_at_ms: float | None, now_ms: float, limit_seconds: float) -> bool:
    """True when the driver's last location is older than the limit (or has no
    timestamp). Pure so it can be tested. The timestamp is written by the
    database server, so a wrong clock on the driver's phone cannot fake freshness."""
    if not updated_at_ms:
        return True
    return (now_ms - updated_at_ms) / 1000.0 > limit_seconds


def decide_alert(eta_minutes: float, final_sent: bool, final_threshold: float) -> str | None:
    """Which alert (if any) to send now: the single 10-minute alert, once.
    Pure function so it can be unit tested without Firebase."""
    if final_sent:
        return None
    if eta_minutes <= final_threshold:
        return FINAL
    return None


def run_once() -> int:
    """Returns the number of notifications sent this cycle (mostly useful
    for tests/logging - the real side effects are the Firestore writes)."""
    location = firebase_client.read_driver_location(settings.BUS_ID)

    global _trip_was_active
    lost = (
        location is not None
        and location.trip_active
        and is_stale(getattr(location, "updated_at", None), time.time() * 1000, settings.LOCATION_STALE_SECONDS)
    )
    if location is None or not location.trip_active or lost:
        if _trip_was_active:
            _trip_was_active = False
            for a in firebase_client.fetch_active_assignments_with_stops(settings.BUS_ID):
                if a.get("tripActive") is True:
                    firebase_client.update_trip_status(a["id"], False, None)
            log.info("bus %s: %s - student statuses cleared", settings.BUS_ID,
                     "location lost (no update for %ss)" % int(settings.LOCATION_STALE_SECONDS) if lost else "trip ended")
        elif lost:
            log.warning("bus %s: trip marked active but the location is stale - ignoring it", settings.BUS_ID)
        else:
            log.info("bus %s: no active trip - nothing to do", settings.BUS_ID)
        return 0

    if location.trip_id is None:
        log.warning("bus %s: trip active but no tripId set - cannot dedupe alerts, skipping", settings.BUS_ID)
        return 0

    _trip_was_active = True
    assignments = firebase_client.fetch_active_assignments_with_stops(settings.BUS_ID)
    sent = 0

    for assignment in assignments:
        student_id = assignment.get("studentId")
        if not student_id:
            continue

        trip = location.trip_id
        final_sent = trip in (assignment.get("alertFinalTripId"), assignment.get("lastAlertTripId"))

        eta_minutes, method = estimate_eta_minutes(
            origin=(location.lat, location.lng),
            dest=(assignment["stopLat"], assignment["stopLng"]),
            avg_speed_kmh=settings.AVG_BUS_SPEED_KMH,
            api_key=settings.MAP_API_KEY,
        )

        now = dt.datetime.now(dt.timezone.utc)
        shown_eta = max(0, round(eta_minutes))
        if should_write_status(assignment.get("tripActive"), assignment.get("etaMinutes"),
                               assignment.get("statusUpdatedAt"), shown_eta, now):
            firebase_client.update_trip_status(assignment["id"], True, shown_eta)

        if final_sent:
            continue  # the alert was already sent; the status above keeps updating

        stage = decide_alert(eta_minutes, final_sent, settings.ALERT_THRESHOLD_MINUTES)
        if stage is None:
            continue

        firebase_client.notify_student_bus(student_id, assignment["stopName"], eta_minutes, stage)
        firebase_client.mark_alert_sent(assignment["id"], trip, stage)
        sent += 1
        log.info("bus %s: %s alert to student %s (%.1f min via %s) for stop %s",
                 settings.BUS_ID, stage, student_id, eta_minutes, method, assignment["stopName"])

    return sent
