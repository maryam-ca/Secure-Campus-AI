"""
Firebase access for the bus ETA job. Reads the live driver location from
Realtime Database (via the Admin SDK, which bypasses the RTDB rule that
blocks students from reading it - this job is the trusted backend, not
a student client), reads bus-stop/assignment configuration from
Firestore, and writes the per-trip dedup marker plus the actual
notification.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import firebase_admin
from firebase_admin import credentials, db as rtdb, firestore, messaging

from app.config import settings

_app: firebase_admin.App | None = None


class FirebaseNotConfiguredError(RuntimeError):
    pass


def init_firebase() -> firebase_admin.App:
    global _app
    if _app is not None:
        return _app
    if not settings.GOOGLE_APPLICATION_CREDENTIALS:
        raise FirebaseNotConfiguredError("GOOGLE_APPLICATION_CREDENTIALS is not set (see .env.example).")
    cred = credentials.Certificate(settings.GOOGLE_APPLICATION_CREDENTIALS)
    _app = firebase_admin.initialize_app(cred, {
        "projectId": settings.FIREBASE_PROJECT_ID or None,
        "databaseURL": settings.FIREBASE_DATABASE_URL or None,
    })
    return _app


def db() -> firestore.Client:
    init_firebase()
    return firestore.client()


@dataclass
class DriverLocation:
    lat: float
    lng: float
    updated_at: float
    trip_active: bool
    trip_id: str | None


def read_driver_location(bus_id: str) -> DriverLocation | None:
    init_firebase()
    if not settings.FIREBASE_DATABASE_URL:
        raise FirebaseNotConfiguredError("FIREBASE_DATABASE_URL is not set.")
    data = rtdb.reference(f"driverLocation/{bus_id}").get()
    if not data:
        return None
    try:
        return DriverLocation(
            lat=float(data["lat"]), lng=float(data["lng"]),
            updated_at=float(data.get("updatedAt", 0)),
            trip_active=bool(data.get("tripActive", False)),
            trip_id=data.get("tripId"),
        )
    except (KeyError, TypeError, ValueError):
        return None


def fetch_active_assignments_with_stops(bus_id: str) -> list[dict[str, Any]]:
    """Returns each busAssignment for this bus joined with its stop's
    coordinates - real Firestore documents Admin configured, nothing
    inferred or invented."""
    assignments = db().collection("busAssignments").where("busId", "==", bus_id).stream()
    out = []
    stop_cache: dict[str, dict[str, Any]] = {}

    for doc in assignments:
        data = doc.to_dict()
        data["id"] = doc.id
        stop_id = data.get("stopId")
        if not stop_id:
            continue
        if stop_id not in stop_cache:
            stop_doc = db().collection("busStops").document(stop_id).get()
            if not stop_doc.exists:
                continue
            stop_cache[stop_id] = stop_doc.to_dict()
        stop = stop_cache[stop_id]
        if "lat" not in stop or "lng" not in stop:
            continue
        data["stopLat"] = stop["lat"]
        data["stopLng"] = stop["lng"]
        data["stopName"] = stop.get("name", stop_id)
        out.append(data)

    return out


def mark_alert_sent(assignment_id: str, trip_id: str) -> None:
    db().collection("busAssignments").document(assignment_id).update({"lastAlertTripId": trip_id})


def notify_student_bus_arriving(student_id: str, stop_name: str, eta_minutes: float) -> None:
    db().collection("notifications").add({
        "recipient": student_id,
        "title": "Campus Bus Alert",
        "message": f"Your assigned campus bus is approximately {round(eta_minutes)} minutes away "
                   f"from your registered stop ({stop_name}).",
        "type": "BUS_10_MIN",
        "isRead": False,
        "metadata": {"stopName": stop_name, "etaMinutes": round(eta_minutes, 1)},
        "createdAt": firestore.SERVER_TIMESTAMP,
    })

    user_doc = db().collection("users").document(student_id).get()
    token = (user_doc.to_dict() or {}).get("fcmToken") if user_doc.exists else None
    if token:
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(
                    title="Campus Bus Alert",
                    body=f"Your bus is about {round(eta_minutes)} min from {stop_name}.",
                ),
                token=token,
            ))
        except Exception:
            pass  # in-app notification above still stands regardless of push delivery
