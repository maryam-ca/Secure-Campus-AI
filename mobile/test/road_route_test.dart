import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:securecampus/services/road_route_service.dart';

Map<String, dynamic> _ok() => {
      'code': 'Ok',
      'routes': [
        {
          'distance': 12345.6,
          'duration': 1500.0,
          'geometry': {
            'coordinates': [
              [72.35, 33.81], // [lng, lat]
              [72.36, 33.80],
              [72.37, 33.78],
            ],
          },
        },
      ],
    };

void main() {
  group('parseOsrmRoute', () {
    test('reads the road line (longitude first in GeoJSON), distance and time', () {
      final r = parseOsrmRoute(_ok())!;
      expect(r.points, [const LatLng(33.81, 72.35), const LatLng(33.80, 72.36), const LatLng(33.78, 72.37)]);
      expect(r.distanceKm, closeTo(12.3456, 1e-6));
      expect(r.durationMinutes, 25);
    });

    test('no route, an error code, or a broken answer gives null (never a made-up line)', () {
      expect(parseOsrmRoute({'code': 'NoRoute'}), isNull);
      expect(parseOsrmRoute({'code': 'Ok', 'routes': []}), isNull);
      expect(parseOsrmRoute({'code': 'Ok', 'routes': [{'geometry': {'coordinates': [[72.3, 33.8]]}}]}), isNull);
      expect(parseOsrmRoute({'code': 'Ok', 'routes': [{'geometry': {'coordinates': [[72.3], [72.4, 33.8]]}}]}), isNull);
    });
  });

  test('routeKey round-trips the places', () {
    final places = [const LatLng(33.81216, 72.35169), const LatLng(33.78468, 72.35787)];
    expect(pointsFromRouteKey(routeKey(places)), places);
    expect(pointsFromRouteKey(''), isEmpty);
  });

  group('RoadRouteService', () {
    final places = [const LatLng(33.81, 72.35), const LatLng(33.78, 72.37)];

    test('asks OSRM with longitude,latitude order and returns the road route', () async {
      late Uri asked;
      final service = RoadRouteService(client: MockClient((req) async {
        asked = req.url;
        return http.Response(jsonEncode(_ok()), 200);
      }));

      final r = await service.fetch(places);

      expect(r, isNotNull);
      expect(asked.path, '/route/v1/driving/72.35,33.81;72.37,33.78');
      expect(asked.queryParameters['overview'], 'full');
      expect(asked.queryParameters['geometries'], 'geojson');
    });

    test('a server error, bad JSON or a network failure all give null', () async {
      expect(await RoadRouteService(client: MockClient((_) async => http.Response('busy', 503))).fetch(places), isNull);
      expect(await RoadRouteService(client: MockClient((_) async => http.Response('not json', 200))).fetch(places), isNull);
      expect(await RoadRouteService(client: MockClient((_) async => throw http.ClientException('offline'))).fetch(places), isNull);
    });

    test('fewer than two places makes no request at all', () async {
      var calls = 0;
      final service = RoadRouteService(client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }));
      expect(await service.fetch([const LatLng(1, 2)]), isNull);
      expect(await service.fetch(const []), isNull);
      expect(calls, 0);
    });
  });
}
