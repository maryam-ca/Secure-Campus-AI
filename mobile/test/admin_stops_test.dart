import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_stops_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final List<Map<String, int>> orderCalls = [];

  @override
  Future<void> applyStopOrder(Map<String, int> newOrders) async => orderCalls.add(newOrders);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BusStopModel _stop(String id, int order) => BusStopModel(id: id, name: 'Stop $id', lat: 33, lng: 73, order: order);

Future<_FakeRepo> _pump(WidgetTester tester, List<BusStopModel> stops) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      busStopsProvider.overrideWith((ref) => Stream.value(stops)),
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
}
