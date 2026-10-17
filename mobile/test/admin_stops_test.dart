import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_stops_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final List<Map<String, int>> orderCalls = [];
  final List<String> deleted = [];
  final List<Map<String, int>> renumberCalls = [];

  @override
  Future<void> applyStopOrder(Map<String, int> newOrders) async => orderCalls.add(newOrders);

  @override
  Future<void> deleteBusStop(String stopId, Map<String, int> renumbered) async {
    deleted.add(stopId);
    renumberCalls.add(renumbered);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BusStopModel _stop(String id, int order) => BusStopModel(id: id, name: 'Stop $id', lat: 33, lng: 73, order: order);

Future<_FakeRepo> _pump(WidgetTester tester, List<BusStopModel> stops, {List<AdminBusAssignmentModel> riders = const []}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      busStopsProvider.overrideWith((ref) => Stream.value(stops)),
      busAssignmentsProvider.overrideWith((ref) => Stream.value(riders)),
    ],
    child: const MaterialApp(home: Scaffold(body: AdminStopsScreen())),
  ));
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('the route is shown in order with an arrow between each pair of stops', (tester) async {
    await _pump(tester, [_stop('A', 1), _stop('B', 2), _stop('C', 3)]);

    expect(find.byKey(const Key('route-summary')), findsOneWidget);
    // 3 stops -> 2 arrows in the route line and 2 in the list
    expect(find.byIcon(Icons.arrow_forward), findsNWidgets(2));
    expect(find.byIcon(Icons.south), findsNWidgets(2));
    expect(find.text('Stop A'), findsNWidgets(2)); // route line + list
  });

  testWidgets('with no stops it says so and shows no arrows', (tester) async {
    await _pump(tester, const []);

    expect(find.text('No stops configured yet.'), findsNWidgets(2));
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(find.byIcon(Icons.south), findsNothing);
  });

  testWidgets('stop arrows reorder the route; the first cannot go up, the last cannot go down', (tester) async {
    final repo = await _pump(tester, [_stop('A', 1), _stop('B', 2), _stop('C', 3)]);

    expect(tester.widget<IconButton>(find.byKey(const Key('stop-up-0'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('stop-down-2'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('stop-down-0')));
    await tester.pump();
    expect(repo.orderCalls.single, {'A': 2, 'B': 1});
  });

  testWidgets('Admin can delete a stop after confirming; the later stops move up', (tester) async {
    final repo = await _pump(tester, [_stop('A', 1), _stop('B', 2), _stop('C', 3)]);

    await tester.tap(find.byKey(const Key('stop-delete-0')));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Stop A"?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['A']);
    expect(repo.renumberCalls.single, {'B': 1, 'C': 2});
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    final repo = await _pump(tester, [_stop('A', 1), _stop('B', 2)]);

    await tester.tap(find.byKey(const Key('stop-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });

  testWidgets('a stop that students ride cannot be deleted', (tester) async {
    final repo = await _pump(tester, [_stop('A', 1), _stop('B', 2)], riders: const [
      AdminBusAssignmentModel(id: 's1', studentId: 's1', studentName: 'Ayesha', stopId: 'B', stopName: 'Stop B'),
    ]);

    await tester.tap(find.byKey(const Key('stop-delete-1')));
    await tester.pumpAndSettle();
    expect(find.text('Cannot delete this stop'), findsOneWidget);
    expect(find.textContaining('1 student is assigned'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });
}
