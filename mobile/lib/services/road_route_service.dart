import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A route that follows real roads: the line to draw plus its length and the
/// driving time OSRM estimates.
class RoadRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RoadRoute({required this.points, required this.distanceMeters, required this.durationSeconds});

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
}

/// Reads an OSRM `route` response (geometries=geojson). Returns null, never a
/// made-up route, if the answer is not a usable route.
RoadRoute? parseOsrmRoute(Map<String, dynamic> json) {
  if (json['code'] != 'Ok') return null;
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty) return null;
  final route = routes.first as Map<String, dynamic>;
  final coords = (route['geometry'] as Map<String, dynamic>?)?['coordinates'];
  if (coords is! List || coords.length < 2) return null;

  final points = <LatLng>[];
  for (final c in coords) {
    // GeoJSON order is [longitude, latitude]
    if (c is! List || c.length < 2) return null;
    points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
  }
  return RoadRoute(
    points: points,
    distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
    durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
  );
}

/// A stable text key for a list of places, so one lookup is shared per route.
String routeKey(List<LatLng> points) =>
    points.map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}').join(';');

List<LatLng> pointsFromRouteKey(String key) => key.isEmpty
    ? const []
    : key.split(';').map((pair) {
        final parts = pair.split(',');
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
      }).toList();

/// Asks the free OpenStreetMap routing service (OSRM, no key, no billing) for
/// the road route through the given places in order. The same service the
/// bus_eta job uses for arrival times.
class RoadRouteService {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  RoadRouteService({http.Client? client, this.baseUrl = 'https://router.project-osrm.org', this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  /// Null when there are fewer than two places, or when the service is
  /// unreachable or finds no route: the caller then shows straight lines and
  /// says so.
  Future<RoadRoute?> fetch(List<LatLng> places) async {
    if (places.length < 2) return null;
    final coords = places.map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coords?overview=full&geometries=geojson');
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;
      return parseOsrmRoute(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
