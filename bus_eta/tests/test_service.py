import time
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app import service
from app.service import FINAL, decide_alert


@pytest.mark.parametrize("eta,final_sent,expected", [
    (30, False, None),     # too far: nothing
    (20.0, False, None),   # no 20-minute alert any more
    (15, False, None),
    (10.0, False, FINAL),  # exactly 10 min: the one alert
    (8, False, FINAL),     # trip started late: sent at once
    (5, True, None),       # already sent: never repeat
    (30, True, None),
])
def test_decide_alert(eta, final_sent, expected):
    assert decide_alert(eta, final_sent, 10) == expected


def _setup(monkeypatch, eta, assignment):
    fc = MagicMock()
    fc.read_driver_location.return_value = SimpleNamespace(trip_active=True, trip_id="T1", lat=1.0, lng=2.0, updated_at=time.time() * 1000)
    fc.fetch_active_assignments_with_stops.return_value = [
        {"id": "a1", "studentId": "s1", "stopName": "Block A", "stopLat": 3.0, "stopLng": 4.0, **assignment}
    ]
    monkeypatch.setattr(service, "firebase_client", fc)
    monkeypatch.setattr(service, "estimate_eta_minutes", lambda **kw: (eta, "test"))
    return fc


def test_only_the_10_minute_alert_is_sent_and_only_once(monkeypatch):
    fc = _setup(monkeypatch, 18, {})
    assert service.run_once() == 0  # 18 min away: no 20-minute alert any more
    fc.notify_student_bus.assert_not_called()

    fc2 = _setup(monkeypatch, 9, {})
    assert service.run_once() == 1
    fc2.notify_student_bus.assert_called_once_with("s1", "Block A", 9, FINAL)
    fc2.mark_alert_sent.assert_called_once_with("a1", "T1", FINAL)

    fc3 = _setup(monkeypatch, 6, {"alertFinalTripId": "T1"})  # same trip, already sent
    assert service.run_once() == 0
    fc3.notify_student_bus.assert_not_called()


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
    fc = _setup(monkeypatch, 9, {"alertFinalTripId": "OLD"})
    assert service.run_once() == 1
    fc.notify_student_bus.assert_called_once()


def test_no_alerts_without_active_trip(monkeypatch):
    fc = _setup(monkeypatch, 5, {})
    fc.read_driver_location.return_value = SimpleNamespace(trip_active=False, trip_id="T1", lat=1.0, lng=2.0)
    assert service.run_once() == 0


# ---------------------------------------------------------------- student trip status
import datetime as dt

from app.service import REFRESH_SECONDS, should_write_status

NOW = dt.datetime(2026, 10, 14, 12, 0, tzinfo=dt.timezone.utc)


@pytest.mark.parametrize("active,eta,updated,new_eta,expected", [
    (None, None, None, 15, True),                                          # never written
    (False, 15, NOW - dt.timedelta(seconds=10), 15, True),                 # trip had been marked ended
    (True, 15, NOW - dt.timedelta(seconds=10), 14, True),                  # minutes changed
    (True, 15, NOW - dt.timedelta(seconds=10), 15, False),                 # same minute, fresh: skip (saves quota)
    (True, 15, NOW - dt.timedelta(seconds=REFRESH_SECONDS + 1), 15, True), # fresh enough no more: refresh
])
def test_should_write_status(active, eta, updated, new_eta, expected):
    assert should_write_status(active, eta, updated, new_eta, NOW) is expected


def test_status_is_written_for_each_student_on_the_first_reading(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", False)
    fc = _setup(monkeypatch, 18, {})
    service.run_once()
    fc.update_trip_status.assert_called_once_with("a1", True, 18)


def test_status_is_not_rewritten_when_unchanged_and_fresh(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", True)
    fresh = dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=15)
    fc = _setup(monkeypatch, 18, {"tripActive": True, "etaMinutes": 18, "statusUpdatedAt": fresh})
    service.run_once()
    fc.update_trip_status.assert_not_called()


def test_status_keeps_updating_after_both_reminders_were_sent(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", True)
    fc = _setup(monkeypatch, 4, {"alertFinalTripId": "T1", "tripActive": True, "etaMinutes": 9,
                                 "statusUpdatedAt": dt.datetime.now(dt.timezone.utc)})
    service.run_once()
    fc.update_trip_status.assert_called_once_with("a1", True, 4)
    fc.notify_student_bus.assert_not_called()  # no third reminder


def test_statuses_are_cleared_once_when_the_trip_ends(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", True)
    fc = _setup(monkeypatch, 5, {"tripActive": True, "etaMinutes": 6})
    fc.read_driver_location.return_value = SimpleNamespace(trip_active=False, trip_id="T1", lat=1.0, lng=2.0)

    service.run_once()
    fc.update_trip_status.assert_called_once_with("a1", False, None)

    fc.update_trip_status.reset_mock()
    service.run_once()  # a later idle cycle does no more work
    fc.update_trip_status.assert_not_called()
    fc.fetch_active_assignments_with_stops.assert_called_once()


# ---------------------------------------------------------------- lost / stale GPS
from app.service import is_stale


def test_is_stale_rules():
    now = 1_000_000_000_000.0
    assert is_stale(None, now, 180) is True                  # never had a timestamp
    assert is_stale(0, now, 180) is True
    assert is_stale(now - 60_000, now, 180) is False         # 1 minute old
    assert is_stale(now - 181_000, now, 180) is True         # just over the limit


def _stale_trip(monkeypatch, age_seconds, assignment=None):
    fc = _setup(monkeypatch, 5, assignment or {})
    fc.read_driver_location.return_value = SimpleNamespace(
        trip_active=True, trip_id="T1", lat=1.0, lng=2.0, updated_at=(time.time() - age_seconds) * 1000)
    return fc


def test_a_stale_location_sends_no_alerts_and_no_status(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", False)
    fc = _stale_trip(monkeypatch, age_seconds=600)
    assert service.run_once() == 0
    fc.notify_student_bus.assert_not_called()
    fc.update_trip_status.assert_not_called()


def test_when_the_location_goes_stale_mid_trip_the_student_statuses_are_cleared_once(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", True)
    fc = _stale_trip(monkeypatch, age_seconds=600, assignment={"tripActive": True, "etaMinutes": 7})
    service.run_once()
    fc.update_trip_status.assert_called_once_with("a1", False, None)

    fc.update_trip_status.reset_mock()
    service.run_once()  # still stale: no repeated work
    fc.update_trip_status.assert_not_called()


def test_a_fresh_location_is_still_used(monkeypatch):
    monkeypatch.setattr(service, "_trip_was_active", False)
    fc = _stale_trip(monkeypatch, age_seconds=20)
    service.run_once()
    fc.update_trip_status.assert_called_once()


# ---------------------------------------------------------------- each student's own stop
def test_each_student_is_alerted_only_for_their_own_stop(monkeypatch):
    fc = MagicMock()
    fc.read_driver_location.return_value = SimpleNamespace(
        trip_active=True, trip_id="T1", lat=1.0, lng=2.0, updated_at=time.time() * 1000)
    fc.fetch_active_assignments_with_stops.return_value = [
        {"id": "a-near", "studentId": "near", "stopName": "Near Stop", "stopLat": 10.0, "stopLng": 10.0},
        {"id": "a-far", "studentId": "far", "stopName": "Far Stop", "stopLat": 50.0, "stopLng": 50.0},
        {"id": "a-none", "studentId": "", "stopName": "No Student", "stopLat": 10.0, "stopLng": 10.0},
    ]
    monkeypatch.setattr(service, "firebase_client", fc)
    # 8 minutes to the near stop, 40 to the far one: the ETA is worked out per stop
    monkeypatch.setattr(service, "estimate_eta_minutes", lambda **kw: (8, "test") if kw["dest"] == (10.0, 10.0) else (40, "test"))

    assert service.run_once() == 1
    fc.notify_student_bus.assert_called_once_with("near", "Near Stop", 8, FINAL)
    fc.mark_alert_sent.assert_called_once_with("a-near", "T1", FINAL)
