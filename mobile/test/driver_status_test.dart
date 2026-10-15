import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/driver_status.dart';

void main() {
  final now = DateTime(2026, 10, 15, 8, 0, 0);

  test('gpsAgeLabel', () {
    expect(gpsAgeLabel(null, now), isNull);
    expect(gpsAgeLabel(now.subtract(const Duration(seconds: 2)), now), 'Just now');
    expect(gpsAgeLabel(now.subtract(const Duration(seconds: 12)), now), '12 s ago');
    expect(gpsAgeLabel(now.subtract(const Duration(seconds: 59)), now), '59 s ago');
    expect(gpsAgeLabel(now.subtract(const Duration(seconds: 190)), now), '3 min ago');
  });

  test('gpsLooksStuck only after 45 seconds, and never without a fix', () {
    expect(gpsLooksStuck(null, now), isFalse);
    expect(gpsLooksStuck(now.subtract(const Duration(seconds: 44)), now), isFalse);
    expect(gpsLooksStuck(now.subtract(const Duration(seconds: 46)), now), isTrue);
  });

  test('tripTimerLabel', () {
    expect(tripTimerLabel(const Duration(seconds: 5)), '00:00:05');
    expect(tripTimerLabel(const Duration(minutes: 42, seconds: 10)), '00:42:10');
    expect(tripTimerLabel(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
  });

  group('friendlyDriverError never shows raw technical text', () {
    test('permission denied', () {
      expect(friendlyDriverError('[firebase_database/permission-denied] Permission denied'), contains('assigned to this bus'));
    });

    test('network problems', () {
      expect(friendlyDriverError('SocketException: Failed host lookup'), contains('No internet'));
      expect(friendlyDriverError('[firebase_database/network-error]'), contains('No internet'));
    });

    test('anything else is a generic sentence', () {
      final msg = friendlyDriverError(StateError('weird'));
      expect(msg, isNot(contains('StateError')));
      expect(msg, contains('end the trip and start it again'));
    });
  });
}
