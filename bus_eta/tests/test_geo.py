from app import geo
from app.geo import estimate_eta_minutes, fallback_eta_minutes, haversine_km


def test_haversine_zero_distance():
    assert haversine_km(33.6844, 73.0479, 33.6844, 73.0479) == 0.0


def test_haversine_known_distance_islamabad_to_lahore():
    # Islamabad (33.6844, 73.0479) to Lahore (31.5497, 74.3436) is a
    # well-known real-world distance, roughly 275km great-circle.
    d = haversine_km(33.6844, 73.0479, 31.5497, 74.3436)
    assert 260 < d < 290, f"expected ~275km, got {d:.1f}km"


def test_haversine_short_campus_distance():
    # Two points ~1.11km apart (0.01 degrees latitude ~ 1.11km)
    d = haversine_km(33.6844, 73.0479, 33.6944, 73.0479)
    assert 1.0 < d < 1.3


def test_fallback_eta_matches_simple_speed_distance_time():
    # 10km at 20km/h should take exactly 30 minutes
    assert fallback_eta_minutes(10.0, 20.0) == 30.0


def test_fallback_eta_rejects_nonpositive_speed():
    import pytest
    with pytest.raises(ValueError):
        fallback_eta_minutes(5.0, 0)


# ---------------------------------------------------------------- road routing (OSRM)
import requests


class _Resp:
    def __init__(self, data, ok=True):
        self._data, self._ok = data, ok

    def raise_for_status(self):
        if not self._ok:
            raise requests.HTTPError("503")

    def json(self):
        return self._data


def _osrm_ok(km):
    return _Resp({"code": "Ok", "routes": [{"distance": km * 1000.0, "duration": 1.0}]})


def _reset_osrm():
    geo._osrm_down_until = 0.0


def test_road_distance_is_used_for_the_eta(monkeypatch):
    _reset_osrm()
    monkeypatch.setattr(geo.requests, "get", lambda *a, **k: _osrm_ok(10.0))
    eta, method = estimate_eta_minutes((33.0, 72.0), (33.0, 72.03), avg_speed_kmh=25)
    assert method == "osrm_road_distance"
    assert eta == 24.0  # 10 km of road / 25 km/h


def test_the_request_is_lng_lat_ordered(monkeypatch):
    _reset_osrm()
    seen = {}

    def fake_get(url, **kw):
        seen["url"] = url
        return _osrm_ok(1.0)

    monkeypatch.setattr(geo.requests, "get", fake_get)
    estimate_eta_minutes((33.5, 72.5), (33.6, 72.6), avg_speed_kmh=25)
    assert "/72.5,33.5;72.6,33.6" in seen["url"]


def test_falls_back_to_straight_line_when_osrm_fails_and_pauses_retries(monkeypatch):
    _reset_osrm()
    calls = []

    def boom(*a, **k):
        calls.append(1)
        raise requests.ConnectionError("down")

    monkeypatch.setattr(geo.requests, "get", boom)
    straight = fallback_eta_minutes(haversine_km(33.0, 72.0, 33.0, 72.03), 25)
    eta, method = estimate_eta_minutes((33.0, 72.0), (33.0, 72.03), avg_speed_kmh=25)
    assert method == "haversine_fallback"
    assert eta == straight
    estimate_eta_minutes((33.0, 72.0), (33.0, 72.03), avg_speed_kmh=25)
    assert len(calls) == 1  # the second call skipped the dead server
    _reset_osrm()


def test_no_route_found_falls_back(monkeypatch):
    _reset_osrm()
    monkeypatch.setattr(geo.requests, "get", lambda *a, **k: _Resp({"code": "NoRoute"}))
    _, method = estimate_eta_minutes((33.0, 72.0), (33.0, 72.03), avg_speed_kmh=25)
    assert method == "haversine_fallback"


def test_routing_can_be_switched_off(monkeypatch):
    _reset_osrm()

    def should_not_be_called(*a, **k):
        raise AssertionError("OSRM must not be called when ROUTING_PROVIDER=straight")

    monkeypatch.setattr(geo.requests, "get", should_not_be_called)
    _, method = estimate_eta_minutes((33.0, 72.0), (33.0, 72.03), avg_speed_kmh=25, provider="straight")
    assert method == "haversine_fallback"


def test_a_google_key_takes_priority(monkeypatch):
    _reset_osrm()
    monkeypatch.setattr(geo, "fetch_routing_eta_minutes", lambda *a, **k: 12.5)
    eta, method = estimate_eta_minutes((33.0, 72.0), (33.0, 72.03), avg_speed_kmh=25, api_key="k")
    assert (eta, method) == (12.5, "routing_api")
