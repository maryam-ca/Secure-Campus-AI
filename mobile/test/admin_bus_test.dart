import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_bus_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/student_model.dart';
import 'package:securecampus/models/transport_models.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final List<Map<String, int>> orderCalls = [];
  final List<String> assigned = [];
  String? failAssignWith;
  bool failSaves = false;

  @override
  Future<String> fetchBusStatus(String busId) async => 'Idle';

  @override
  Future<void> applyStopOrder(Map<String, int> newOrders) async => orderCalls.add(newOrders);

  @override
  Future<void> setCampus(String name, double lat, double lng) async {
    if (failSaves) throw Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.');
  }

  @override
  Future<void> assignStudentToBus({
    required String studentId,
    required String studentName,
    required String busId,
    required String stopId,
    required String stopName,
  }) async {
    if (failAssignWith != null) throw StateError(failAssignWith!);
    assigned.add(studentId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BusStopModel _stop(String id, int order) => BusStopModel(id: id, name: 'Stop $id', lat: 33, lng: 73, order: order);

const _student = StudentModel(
  uid: 'u1',
  registrationNumber: 'FA23-BSE-001',
  name: 'Ayesha Khan',
  program: 'BSE',
  semester: 5,
  email: 'a@x.pk',
  courseIds: [],
  irisEnrolled: false,
);

Future<_FakeRepo> _pump(
  WidgetTester tester, {
  CampusLocation? campus,
  List<AdminBusAssignmentModel> assignments = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      busStopsProvider.overrideWith((ref) => Stream.value([_stop('A', 1), _stop('B', 2), _stop('C', 3)])),
      busAssignmentsProvider.overrideWith((ref) => Stream.value(assignments)),
      driverLocationProvider.overrideWith((ref, id) => Stream.value(null)),
      campusLocationProvider.overrideWith((ref) => Stream.value(campus)),
      allStudentsProvider.overrideWith((ref) => Stream.value([_student])),
    ],
    child: const MaterialApp(home: Scaffold(body: AdminBusScreen())),
  ));
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('shows a prompt when the campus is not set, and no seat count anywhere', (tester) async {
    await _pump(tester);
    expect(find.text('Campus location not set'), findsOneWidget);
    expect(find.textContaining('seat'), findsNothing);
    expect(find.textContaining('Seats'), findsNothing);
  });

  testWidgets('the campus dialog names the field that is wrong', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    // coordinates fine, name empty: only the name is flagged
    await tester.enterText(find.byKey(const Key('campus-lat-field')), '33.78099');
    await tester.enterText(find.byKey(const Key('campus-lng-field')), '72.35105');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the campus name'), findsOneWidget);
    expect(find.text('A number from -90 to 90'), findsNothing);
    expect(find.text('A number from -180 to 180'), findsNothing);

    // name given, longitude out of range: only the longitude is flagged
    await tester.enterText(find.byKey(const Key('campus-name-field')), 'COMSATS Attock');
    await tester.enterText(find.byKey(const Key('campus-lng-field')), '200');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the campus name'), findsNothing);
    expect(find.text('A number from -180 to 180'), findsOneWidget);
  });

  testWidgets('a refused save says so instead of doing nothing', (tester) async {
    final repo = await _pump(tester);
    repo.failSaves = true;

    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campus-name-field')), 'COMSATS Attock');
    await tester.enterText(find.byKey(const Key('campus-lat-field')), '33.78099');
    await tester.enterText(find.byKey(const Key('campus-lng-field')), '72.35105');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campus-save-error')), findsOneWidget);
    expect(find.textContaining('rules may not be published'), findsOneWidget);
    expect(find.text('Campus location'), findsOneWidget); // dialog stays open
  });

  testWidgets('shows the campus once set', (tester) async {
    await _pump(tester, campus: const CampusLocation(name: 'CUI Attock', lat: 33.77, lng: 72.36));
    expect(find.text('CUI Attock'), findsOneWidget);
  });
}
