from app.geo import fallback_eta_minutes, haversine_km


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
