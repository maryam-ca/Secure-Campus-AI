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
  int? savedSeats;
  String? failAssignWith;

  @override
  Future<String> fetchBusStatus(String busId) async => 'Idle';

  @override
  Future<void> applyStopOrder(Map<String, int> newOrders) async => orderCalls.add(newOrders);

  @override
  Future<void> setBusCapacity(String busId, int capacity) async => savedSeats = capacity;

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
  int? capacity,
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
      busInfoProvider.overrideWith((ref, id) => Stream.value(BusInfo(id: id, capacity: capacity))),
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
  testWidgets('shows seats and a prompt when the campus is not set', (tester) async {
    await _pump(tester, capacity: 40, assignments: [
      const AdminBusAssignmentModel(id: 's1', studentId: 's1', studentName: 'One', stopId: 'A', stopName: 'Stop A'),
    ]);
    expect(find.text('Seats 40 · Assigned 1 · Free 39'), findsOneWidget);
    expect(find.text('Campus location not set'), findsOneWidget);
  });

  testWidgets('prompts for the seat count when it is not set', (tester) async {
    await _pump(tester);
    expect(find.text('0 assigned · seat count not set'), findsOneWidget);
  });

  testWidgets('shows the campus once set', (tester) async {
    await _pump(tester, campus: const CampusLocation(name: 'CUI Attock', lat: 33.77, lng: 72.36));
    expect(find.text('CUI Attock'), findsOneWidget);
  });

  testWidgets('the Admin can save a seat count, and a bad number is rejected', (tester) async {
    final repo = await _pump(tester, capacity: 40);
    await tester.tap(find.text('Set seats'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('seats-field')), '0');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a whole number from 1 to 200.'), findsOneWidget);
    expect(repo.savedSeats, isNull);

    await tester.enterText(find.byKey(const Key('seats-field')), '32');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.savedSeats, 32);
  });

  testWidgets('a full bus: the dialog stays open and says why', (tester) async {
    final repo = await _pump(tester, capacity: 1);
    repo.failAssignWith = 'This bus is full: all 1 seats are already assigned. Remove a student or raise the seat count first.';

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayesha Khan (FA23-BSE-001)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registered stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assign-error')), findsOneWidget);
    expect(find.textContaining('bus is full'), findsOneWidget);
    expect(repo.assigned, isEmpty);
    expect(find.text('Assign Student to Bus'), findsOneWidget);
  });
}
