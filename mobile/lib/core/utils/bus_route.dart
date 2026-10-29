import 'package:latlong2/latlong.dart';

import '../../models/admin_models.dart';
import '../../models/transport_models.dart';

/// The route's stop order: pure functions, so the rules are tested without Firebase.

/// New `order` values after moving the stop at [index] one place up (delta -1)
/// or down (+1). Returns stop id -> new order for every stop whose order
/// changed, renumbered 1..n so gaps and duplicates in old data are repaired;
/// empty if the move is not possible (already first/last).
Map<String, int> reorderedStops(List<BusStopModel> stops, int index, int delta) {
  final target = index + delta;
  if (index < 0 || index >= stops.length || target < 0 || target >= stops.length) return const {};
  final sorted = [...stops]..sort((a, b) => a.order.compareTo(b.order));
  final moved = sorted.removeAt(index);
  sorted.insert(target, moved);

  final changes = <String, int>{};
  for (var i = 0; i < sorted.length; i++) {
    final newOrder = i + 1;
    if (sorted[i].order != newOrder) changes[sorted[i].id] = newOrder;
  }
  return changes;
}

/// The stops in the order the bus visits them: ascending when going TO campus
/// (pick up, then arrive), reversed when going FROM campus (leave, then drop off).
List<BusStopModel> stopsInTripOrder(List<BusStopModel> stops, {required bool toCampus}) {
  final sorted = [...stops]..sort((a, b) => a.order.compareTo(b.order));
  return toCampus ? sorted : sorted.reversed.toList();
}

/// New `order` values for the stops that remain after [removedId] is deleted,
/// renumbered 1..n in route order so no gap is left. Only stops whose order
/// changes are included.
Map<String, int> renumberedAfterRemoving(List<BusStopModel> stops, String removedId) {
  final remaining = stops.where((s) => s.id != removedId).toList()..sort((a, b) => a.order.compareTo(b.order));
  final changes = <String, int>{};
  for (var i = 0; i < remaining.length; i++) {
    if (remaining[i].order != i + 1) changes[remaining[i].id] = i + 1;
  }
  return changes;
}

/// The next free stop ID: STOP-01, STOP-02, ... continuing after the highest
/// number already used (so deleting a middle stop never reuses a live ID, and
/// the Admin never has to invent IDs).
String nextStopId(Iterable<String> existingIds) {
  final taken = existingIds.toSet();
  var highest = 0;
  for (final id in taken) {
    final m = RegExp(r'(\d+)$').firstMatch(id);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n > highest) highest = n;
    }
  }
  var n = highest + 1;
  String format(int v) => 'STOP-${v.toString().padLeft(2, '0')}';
  while (taken.contains(format(n))) {
    n++;
  }
  return format(n);
}

/// Route position for a stop added now: the end of the route.
int nextStopOrder(List<BusStopModel> stops) =>
    stops.isEmpty ? 1 : stops.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 1;

/// The points of the morning route in travel order: every stop in route order,
/// then the campus (if set). The first point is where the bus starts.
List<LatLng> routePoints(List<BusStopModel> stops, CampusLocation? campus) {
  final sorted = [...stops]..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (final s in sorted) LatLng(s.lat, s.lng),
    if (campus != null) LatLng(campus.lat, campus.lng),
  ];
}
