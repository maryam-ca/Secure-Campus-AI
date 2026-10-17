"""
Distance/ETA calculation. Real methods, never a made-up number:

1. `fetch_routing_eta_minutes` - Google Distance Matrix, used when MAP_API_KEY
   is set: real roads and live traffic. (Paid; needs a billing account.)
2. `fetch_osrm_road_km` - free OpenStreetMap road routing (OSRM, no key): the
   real road distance along the road network. The ETA is that road distance
   divided by the assumed bus speed (AVG_BUS_SPEED_KMH), so it uses the same
   speed assumption as the straight-line estimate but a real route. It does
   not know about traffic.
3. `haversine_km` - straight-line (great-circle) distance. Always available,
   no external dependency. Used only when routing is switched off
   (ROUTING_PROVIDER=straight) or the routing call fails.

`estimate_eta_minutes` tries them in that order and reports which one it used,
so the coarser fallback is never presented as routing-accurate.
"""

from __future__ import annotations

import math
import time

import requests

EARTH_RADIUS_KM = 6371.0088


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)

    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_KM * c


def fallback_eta_minutes(distance_km: float, avg_speed_kmh: float) -> float:
    if avg_speed_kmh <= 0:
        raise ValueError("avg_speed_kmh must be positive")
    return (distance_km / avg_speed_kmh) * 60.0


def fetch_routing_eta_minutes(origin: tuple[float, float], dest: tuple[float, float],
                               api_key: str, timeout_s: float = 5.0) -> float | None:
    """Real HTTP call to the Google Distance Matrix API. Returns None
    (never a fake number) if the key is missing, the call fails, or the
    response doesn't contain a usable route - callers must then fall
    back to `fallback_eta_minutes` explicitly."""
    if not api_key:
        return None

    try:
        resp = requests.get(
            "https://maps.googleapis.com/maps/api/distancematrix/json",
            params={
                "origins": f"{origin[0]},{origin[1]}",
                "destinations": f"{dest[0]},{dest[1]}",
                "departure_time": "now",
                "key": api_key,
            },
            timeout=timeout_s,
        )
        resp.raise_for_status()
        data = resp.json()
        element = data["rows"][0]["elements"][0]
        if element.get("status") != "OK":
            return None
        duration_s = element.get("duration_in_traffic", element["duration"])["value"]
        return duration_s / 60.0
    except (requests.RequestException, KeyError, IndexError, ValueError):
        return None


# After a failed OSRM call, skip it for a while so a down server does not slow
# every polling cycle (each failed attempt can wait for the timeout).
OSRM_RETRY_AFTER_SECONDS = 60.0
_osrm_down_until = 0.0


def fetch_osrm_road_km(origin: tuple[float, float], dest: tuple[float, float],
                        base_url: str = "https://router.project-osrm.org", timeout_s: float = 5.0) -> float | None:
    """Road distance in km along the real road network, from OpenStreetMap data
    via OSRM. Returns None (never a fake number) if the call fails or no route
    exists; the caller then falls back to the straight-line distance."""
    global _osrm_down_until
    if time.monotonic() < _osrm_down_until:
        return None
    try:
        resp = requests.get(
            f"{base_url.rstrip('/')}/route/v1/driving/{origin[1]},{origin[0]};{dest[1]},{dest[0]}",
            params={"overview": "false"},
            timeout=timeout_s,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("code") != "Ok":
            return None
        return float(data["routes"][0]["distance"]) / 1000.0
    except (requests.RequestException, KeyError, IndexError, ValueError, TypeError):
        _osrm_down_until = time.monotonic() + OSRM_RETRY_AFTER_SECONDS
        return None


def estimate_eta_minutes(origin: tuple[float, float], dest: tuple[float, float],
                          avg_speed_kmh: float, api_key: str = "",
                          provider: str = "osrm",
                          osrm_url: str = "https://router.project-osrm.org") -> tuple[float, str]:
    """Returns (eta_minutes, method). method is 'routing_api' (Google),
    'osrm_road_distance' (real road distance / avg speed) or
    'haversine_fallback' (straight line / avg speed), so callers can log or
    display which one was used."""
    routing_eta = fetch_routing_eta_minutes(origin, dest, api_key) if api_key else None
    if routing_eta is not None:
        return routing_eta, "routing_api"

    if provider == "osrm":
        road_km = fetch_osrm_road_km(origin, dest, osrm_url)
        if road_km is not None:
            return fallback_eta_minutes(road_km, avg_speed_kmh), "osrm_road_distance"

    distance = haversine_km(*origin, *dest)
    return fallback_eta_minutes(distance, avg_speed_kmh), "haversine_fallback"
