"""
Distance/ETA calculation. Two real methods, never a made-up number:

1. `haversine_km` - real great-circle distance between two lat/lng
   points. Always available, no external dependency.
2. `fetch_routing_eta_minutes` - a real call to a routing API (Google
   Distance Matrix-compatible) when MAP_API_KEY is configured, which
   accounts for actual roads/traffic instead of a straight line.

`estimate_eta_minutes` prefers the routing API and falls back to
haversine distance / average speed only if no API key is configured or
the API call fails - and the fallback is clearly a coarser estimate,
not a hidden substitute pretending to be routing-accurate.
"""

from __future__ import annotations

import math

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


def estimate_eta_minutes(origin: tuple[float, float], dest: tuple[float, float],
                          avg_speed_kmh: float, api_key: str = "") -> tuple[float, str]:
    """Returns (eta_minutes, method) where method is 'routing_api' or
    'haversine_fallback' - callers can log/display which one was used
    rather than presenting a fallback estimate as if it were precise."""
    routing_eta = fetch_routing_eta_minutes(origin, dest, api_key) if api_key else None
    if routing_eta is not None:
        return routing_eta, "routing_api"

    distance = haversine_km(*origin, *dest)
    return fallback_eta_minutes(distance, avg_speed_kmh), "haversine_fallback"
