import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_stops_screen.dart';
import 'package:securecampus/features/admin/map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/transport_models.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final List<Map<String, int>> orderCalls = [];
  final List<String> deleted = [];
  final List<Map<String, int>> renumberCalls = [];
  final List<({String id, String name, double lat, double lng, int order})> added = [];
  final List<({String id, String name, double lat, double lng})> updated = [];

  @override
  Future<void> updateBusStop(String stopId, String name, double lat, double lng) async =>
      updated.add((id: stopId, name: name, lat: lat, lng: lng));

  @override
  Future<void> upsertBusStop(String id, String name, double lat, double lng, int order) async =>
      added.add((id: id, name: name, lat: lat, lng: lng, order: order));

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

Future<_FakeRepo> _pump(WidgetTester tester, List<BusStopModel> stops,
    {List<AdminBusAssignmentModel> riders = const [], CampusLocation? campus}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      busStopsProvider.overrideWith((ref) => Stream.value(stops)),
      busAssignmentsProvider.overrideWith((ref) => Stream.value(riders)),
      campusLocationProvider.overrideWith((ref) => Stream.value(campus)),
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

  group('route map and choosing places on the map', () {
    testWidgets('with stops and a campus the route map is shown', (tester) async {
      await _pump(tester, [_stop('A', 1), _stop('B', 2)],
          campus: const CampusLocation(name: 'CUI Attock', lat: 33.77, lng: 72.36));
      expect(find.byKey(const Key('route-map')), findsOneWidget);
      expect(find.textContaining('Green = where the morning bus starts'), findsOneWidget);
    });

    testWidgets('with nothing set the map card says what to do', (tester) async {
      await _pump(tester, const []);
      expect(find.byKey(const Key('route-map')), findsNothing);
      expect(find.textContaining('Add the first stop'), findsOneWidget);
    });

    testWidgets('a stop needs a name and a location chosen on the map', (tester) async {
      final repo = await _pump(tester, const []);
      await tester.tap(find.byKey(const Key('add-stop-on-map')));
      await tester.pumpAndSettle();
      expect(find.text('This will be stop 1, where the morning bus starts.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stop-add')));
      await tester.pump();
      expect(find.text('Enter a name for the stop.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('stop-name-field')), 'Main Chowk');
      await tester.tap(find.byKey(const Key('stop-add')));
      await tester.pump();
      expect(find.text('Choose the stop location on the map.'), findsOneWidget);
      expect(repo.added, isEmpty);
    });

    testWidgets('Choose location on map opens the picker, with Use disabled until a place is chosen', (tester) async {
      await _pump(tester, [_stop('STOP-01', 1), _stop('STOP-02', 2)]);
      await tester.tap(find.byKey(const Key('add-stop-on-map')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('stop-name-field')), 'Main Chowk');

      await tester.tap(find.byKey(const Key('stop-pick-on-map')));
      await tester.pumpAndSettle();
      expect(find.byType(MapPickerScreen), findsOneWidget);
      // Nothing chosen yet: the confirm button is disabled.
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('picker-use'))).onPressed, isNull);
    });
  });

  group('editing a stop', () {
    testWidgets('the edit dialog opens with the current name and location', (tester) async {
      await _pump(tester, [_stop('A', 1), _stop('B', 2)]);
      await tester.tap(find.byKey(const Key('stop-edit-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Bus Stop'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('stop-name-field'))).controller!.text, 'Stop B');
      expect(find.text('Location: 33.00000, 73.00000'), findsOneWidget);
      expect(find.text('Change location on map'), findsOneWidget);
      expect(find.textContaining('keeps its place in the route'), findsOneWidget);
    });

    testWidgets('renaming saves the same stop (same ID, same place) and adds nothing new', (tester) async {
      final repo = await _pump(tester, [_stop('A', 1), _stop('B', 2)]);
      await tester.tap(find.byKey(const Key('stop-edit-0')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('stop-name-field')), 'Main Chowk');
      await tester.tap(find.byKey(const Key('stop-add')));
      await tester.pumpAndSettle();

      expect(repo.updated, [(id: 'A', name: 'Main Chowk', lat: 33.0, lng: 73.0)]);
      expect(repo.added, isEmpty);
      expect(find.text('Edit Bus Stop'), findsNothing);
    });

    testWidgets('an empty name is refused', (tester) async {
      final repo = await _pump(tester, [_stop('A', 1)]);
      await tester.tap(find.byKey(const Key('stop-edit-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('stop-name-field')), '   ');
      await tester.tap(find.byKey(const Key('stop-add')));
      await tester.pump();
      expect(find.text('Enter a name for the stop.'), findsOneWidget);
      expect(repo.updated, isEmpty);
    });
  });

  group('MapPickerScreen', () {
    Future<LatLng?> openPicker(WidgetTester tester, {LatLng? initial}) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      LatLng? result;
      var popped = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<LatLng>(
                    MaterialPageRoute(builder: (_) => MapPickerScreen(title: 'Choose', initial: initial)),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (initial != null) {
        await tester.tap(find.byKey(const Key('picker-use')));
        await tester.pumpAndSettle();
        expect(popped, isTrue);
      }
      return result;
    }

    testWidgets('nothing chosen: prompts to tap the map and Use is disabled', (tester) async {
      await openPicker(tester);
      expect(find.text('Tap the map to place the pin (zoom in for accuracy).'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('picker-use'))).onPressed, isNull);
    });

    testWidgets('an existing location is shown, and Use returns it', (tester) async {
      final r = await openPicker(tester, initial: const LatLng(33.77, 72.36));
      expect(r, const LatLng(33.77, 72.36));
    });
  });
}
