/// Plain-language pieces of the driver screen, kept pure so they are tested
/// without a phone or GPS.

/// How fresh the last GPS fix is, for the driver: "Just now", "12 s ago",
/// "3 min ago". Null when there has been no fix yet.
String? gpsAgeLabel(DateTime? lastFix, DateTime now) {
  if (lastFix == null) return null;
  final seconds = now.difference(lastFix).inSeconds;
  if (seconds < 5) return 'Just now';
  if (seconds < 60) return '$seconds s ago';
  return '${seconds ~/ 60} min ago';
}

/// A fix older than this means students are NOT getting live updates (the
/// server stops trusting a location after 3 minutes; warn the driver sooner).
const Duration gpsWarnAfter = Duration(seconds: 45);

bool gpsLooksStuck(DateTime? lastFix, DateTime now) =>
    lastFix != null && now.difference(lastFix) > gpsWarnAfter;

/// "00:42:10" for the trip timer.
String tripTimerLabel(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// Turns a technical failure into one sentence a driver can act on.
String friendlyDriverError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission-denied') || text.contains('permission_denied') || text.contains('permission denied')) {
    return 'The server refused the location update. Ask the Admin to check that you are assigned to this bus.';
  }
  if (text.contains('network') || text.contains('unavailable') || text.contains('socket') || text.contains('timeout')) {
    return 'No internet connection. Live location is not reaching students; it will resume when you are back online.';
  }
  if (text.contains('location service') || text.contains('gps')) {
    return 'GPS is not available. Check that location is turned on.';
  }
  return 'Something went wrong while sharing your location. If it keeps happening, end the trip and start it again.';
}
