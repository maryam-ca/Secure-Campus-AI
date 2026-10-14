import '../../models/admin_models.dart';

/// Seat arithmetic and the route's stop order: pure functions, so the rules
/// are tested without Firebase.

/// Why this student cannot be assigned to the bus, or null if they can.
///
/// * No capacity set yet: no limit (the Admin screen nudges to set one).
/// * A student who already has a seat can be moved to another stop: that does
///   not use an extra seat.
/// * Otherwise the bus must have a free seat.
String? cannotAssignReason({
  required int? capacity,
  required Iterable<String> assignedStudentIds,
  required String studentId,
}) {
  if (capacity == null) return null;
  final assigned = assignedStudentIds.toSet();
  if (assigned.contains(studentId)) return null;
  if (assigned.length >= capacity) {
    return 'This bus is full: all $capacity seats are already assigned. '
        'Remove a student or raise the seat count first.';
  }
  return null;
}

/// "Seats 40 · Assigned 24 · Free 16", or a prompt when the seats are not set.
String seatSummary({required int? capacity, required int assigned}) {
  if (capacity == null) return '$assigned assigned · seat count not set';
  final free = capacity - assigned;
  return free >= 0 ? 'Seats $capacity · Assigned $assigned · Free $free' : 'Seats $capacity · Assigned $assigned · OVER by ${-free}';
}

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
