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
  testWidgets('no seat count anywhere, and the campus is not set here (it lives on the Stops page)', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('campus-tile')), findsNothing);
    expect(find.textContaining('seat'), findsNothing);
    expect(find.textContaining('Seats'), findsNothing);
  });
}
