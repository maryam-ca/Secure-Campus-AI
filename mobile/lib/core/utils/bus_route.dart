import '../../models/admin_models.dart';

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
