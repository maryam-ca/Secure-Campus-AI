import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:securecampus/features/driver/driver_dashboard_screen.dart';
import 'package:securecampus/providers/auth_provider.dart';
import 'package:securecampus/repositories/driver_repository.dart';
import 'package:securecampus/services/auth_service.dart';

class _FakeAuth extends Fake implements AuthService {
  final List<String> log;
  _FakeAuth(this.log);

  @override
  Future<void> signOut() async => log.add('signOut');
}

class _FakeUser implements User {
  @override
  String get uid => 'driver-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements DriverRepository {
  String? busId = 'BUS-001';
  bool markedActive = false;
  bool failWrites = false;
  final events = <String>[];
  final fixes = <(double, double)>[];

  @override
  Future<String?> fetchAssignedBusId(String driverUid) async => busId;

  @override
  Future<bool> isTripMarkedActive(String busId) async => markedActive;

  @override
  Future<void> armAutoEnd(String busId) async => events.add('arm');

  @override
  Future<void> cancelAutoEnd(String busId) async => events.add('cancel');

  @override
  Future<void> pushLocation({
    required String busId,
    required double lat,
    required double lng,
    required bool tripActive,
    required String tripId,
  }) async {
    if (failWrites) throw StateError('[firebase_database/permission-denied] Permission denied');
    fixes.add((lat, lng));
  }

  @override
  Future<void> markTripStopped({required String busId, required String tripId}) async => events.add('stopped');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSource implements DriverLocationSource {
  String? problem;
  final controller = StreamController<Position>.broadcast();

  @override
  Future<String?> checkReady() async => problem;

  @override
  Stream<Position> positions() => controller.stream;
}

Position _fix(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

DateTime _clockNow = DateTime(2026, 10, 15, 8);

Future<void> _pump(WidgetTester tester, _FakeRepo repo, _FakeSource source, {List<String>? authLog}) async {
  _clockNow = DateTime(2026, 10, 15, 8);
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      driverRepositoryProvider.overrideWithValue(repo),
      driverLocationSourceProvider.overrideWithValue(source),
      driverClockProvider.overrideWithValue(() => _clockNow),
      authServiceProvider.overrideWithValue(_FakeAuth(authLog ?? [])),
      firebaseAuthStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
      // the shared shell shows who is signed in; no Firebase in tests
      currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: const MaterialApp(home: DriverDashboardScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

/// Unmounts the screen so its timers are cancelled before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('a driver with no bus is told to contact the Admin', (tester) async {
    final repo = _FakeRepo()..busId = null;
    await _pump(tester, repo, _FakeSource());
    expect(find.textContaining('not currently assigned'), findsOneWidget);
  });

  testWidgets('a trip left marked live by a closed app is ended, and the driver is told', (tester) async {
    final repo = _FakeRepo()..markedActive = true;
    await _pump(tester, repo, _FakeSource());
    expect(repo.events, contains('stopped'));
    expect(find.textContaining('still marked live'), findsOneWidget);
  });

  testWidgets('GPS off: a plain message and no trip is started', (tester) async {
    final repo = _FakeRepo();
    final source = _FakeSource()..problem = 'Location is turned off on this phone. Turn on GPS and try again.';
    await _pump(tester, repo, source);

    await tester.tap(find.text('Start Trip'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('driver-error')), findsOneWidget);
    expect(find.textContaining('Turn on GPS'), findsOneWidget);
    expect(find.text('Start Trip'), findsOneWidget);
    expect(repo.events, isNot(contains('arm')));
  });

  testWidgets('start: the server is told to end the trip if the phone drops, fixes are sent, End Trip stops it', (tester) async {
    final repo = _FakeRepo();
    final source = _FakeSource();
    await _pump(tester, repo, source);

    await tester.tap(find.text('Start Trip'));
    await tester.pump();
    await tester.pump();
    expect(repo.events, ['arm']);
    expect(find.text('LIVE: sharing location'), findsOneWidget);

    source.controller.add(_fix(33.77, 72.36));
    await tester.pump();
    await tester.pump();
    expect(repo.fixes, [(33.77, 72.36)]);
    expect(find.text('Just now'), findsOneWidget);
    expect(find.text('33.77000, 72.36000'), findsOneWidget);

    await tester.tap(find.text('End Trip'));
    await tester.pumpAndSettle();
    expect(find.text('End this trip?'), findsOneWidget);
    await tester.tap(find.text('End Trip').last);
    await tester.pumpAndSettle();
    expect(repo.events, ['arm', 'stopped']);
    expect(find.text('Start Trip'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('no new GPS fix for a while shows a clear warning', (tester) async {
    final repo = _FakeRepo();
    final source = _FakeSource();
    await _pump(tester, repo, source);
    await tester.tap(find.text('Start Trip'));
    await tester.pump();
    await tester.pump();
    source.controller.add(_fix(33.0, 72.0));
    await tester.pump();
    expect(find.byKey(const Key('gps-stuck')), findsNothing);

    _clockNow = _clockNow.add(const Duration(seconds: 50));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('gps-stuck')), findsOneWidget);
    expect(find.textContaining('Students are not getting live updates'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a refused or failing write shows a friendly sentence, not the raw error', (tester) async {
    final repo = _FakeRepo()..failWrites = true;
    final source = _FakeSource();
    await _pump(tester, repo, source);
    await tester.tap(find.text('Start Trip'));
    await tester.pump();
    await tester.pump();

    source.controller.add(_fix(33.0, 72.0));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('assigned to this bus'), findsOneWidget);
    expect(find.textContaining('firebase_database'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('signing out during a live trip ends the trip first', (tester) async {
    final repo = _FakeRepo();
    final source = _FakeSource();
    final log = <String>[];
    await _pump(tester, repo, source, authLog: log);
    await tester.tap(find.text('Start Trip'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Open navigation menu')); // Sign out lives in the sidebar
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await tester.pump();

    expect(repo.events, ['arm', 'stopped']);
    expect(log, ['signOut']);
    await _unmount(tester);
  });
}
