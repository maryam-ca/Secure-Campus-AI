import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/road_route_service.dart';

final roadRouteServiceProvider = Provider<RoadRouteService>((ref) => RoadRouteService());

/// The road route for one list of places, identified by [routeKey]. Resolves
/// to null if the routing service cannot give a route.
final roadRouteProvider = FutureProvider.autoDispose.family<RoadRoute?, String>((ref, key) {
  return ref.watch(roadRouteServiceProvider).fetch(pointsFromRouteKey(key));
});
