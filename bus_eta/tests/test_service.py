from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app import service
from app.service import FINAL, FIRST, decide_alert


@pytest.mark.parametrize("eta,first_sent,final_sent,expected", [
    (30, False, False, None),     # too far: nothing yet
    (20.0, False, False, FIRST),  # exactly 20 min: "get ready"
    (15, False, False, FIRST),
    (15, True, False, None),      # already told to get ready
    (10.0, True, False, FINAL),   # exactly 10 min: final
    (8, True, False, FINAL),
    (8, False, False, FINAL),     # trip started late: skip "get ready", send final only
    (5, True, True, None),        # both done: never repeat
    (5, False, True, None),
])
def test_decide_alert(eta, first_sent, final_sent, expected):
    assert decide_alert(eta, first_sent, final_sent, 20, 10) == expected


def _setup(monkeypatch, eta, assignment):
    fc = MagicMock()
    fc.read_driver_location.return_value = SimpleNamespace(trip_active=True, trip_id="T1", lat=1.0, lng=2.0)
    fc.fetch_active_assignments_with_stops.return_value = [
        {"id": "a1", "studentId": "s1", "stopName": "Block A", "stopLat": 3.0, "stopLng": 4.0, **assignment}
    ]
    monkeypatch.setattr(service, "firebase_client", fc)
    monkeypatch.setattr(service, "estimate_eta_minutes", lambda **kw: (eta, "test"))
    return fc


def test_first_alert_then_final_alert_each_once(monkeypatch):
    fc = _setup(monkeypatch, 18, {})
    assert service.run_once() == 1
    fc.notify_student_bus.assert_called_once_with("s1", "Block A", 18, FIRST)
    fc.mark_alert_sent.assert_called_once_with("a1", "T1", FIRST)

    # same student, same trip, now 9 minutes away and the first alert is recorded
    fc2 = _setup(monkeypatch, 9, {"alertFirstTripId": "T1"})
    assert service.run_once() == 1
    fc2.notify_student_bus.assert_called_once_with("s1", "Block A", 9, FINAL)
    fc2.mark_alert_sent.assert_called_once_with("a1", "T1", FINAL)


def test_nothing_sent_when_far_or_already_done(monkeypatch):
    fc = _setup(monkeypatch, 45, {})
    assert service.run_once() == 0
    fc.notify_student_bus.assert_not_called()

    fc = _setup(monkeypatch, 5, {"alertFinalTripId": "T1"})
    assert service.run_once() == 0
    fc.notify_student_bus.assert_not_called()


def test_legacy_last_alert_field_still_blocks_repeat(monkeypatch):
    fc = _setup(monkeypatch, 5, {"lastAlertTripId": "T1"})
    assert service.run_once() == 0
    fc.notify_student_bus.assert_not_called()


def test_new_trip_alerts_again(monkeypatch):
    fc = _setup(monkeypatch, 18, {"alertFirstTripId": "OLD", "alertFinalTripId": "OLD"})
    assert service.run_once() == 1
    fc.notify_student_bus.assert_called_once()


def test_no_alerts_without_active_trip(monkeypatch):
    fc = _setup(monkeypatch, 5, {})
    fc.read_driver_location.return_value = SimpleNamespace(trip_active=False, trip_id="T1", lat=1.0, lng=2.0)
    assert service.run_once() == 0
