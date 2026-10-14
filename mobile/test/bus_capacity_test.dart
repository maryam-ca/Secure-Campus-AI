import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/bus_capacity.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/transport_models.dart';

BusStopModel _stop(String id, int order) => BusStopModel(id: id, name: 'Stop $id', lat: 33.0, lng: 73.0, order: order);

void main() {
  group('cannotAssignReason', () {
    test('a free seat means the student can be assigned', () {
      expect(cannotAssignReason(capacity: 3, assignedStudentIds: ['a', 'b'], studentId: 'c'), isNull);
    });

    test('a full bus blocks a new student, with a clear message', () {
      final why = cannotAssignReason(capacity: 2, assignedStudentIds: ['a', 'b'], studentId: 'c');
      expect(why, contains('bus is full'));
      expect(why, contains('2 seats'));
    });

    test('moving a student who already has a seat does not need a free seat', () {
      expect(cannotAssignReason(capacity: 2, assignedStudentIds: ['a', 'b'], studentId: 'b'), isNull);
    });

    test('no capacity set means no limit yet', () {
      expect(cannotAssignReason(capacity: null, assignedStudentIds: List.generate(500, (i) => 's$i'), studentId: 'x'), isNull);
    });

    test('duplicates in the list are counted once', () {
      expect(cannotAssignReason(capacity: 2, assignedStudentIds: ['a', 'a', 'b'], studentId: 'c'), contains('full'));
      expect(cannotAssignReason(capacity: 3, assignedStudentIds: ['a', 'a', 'b'], studentId: 'c'), isNull);
    });
  });

  test('seatSummary', () {
    expect(seatSummary(capacity: 40, assigned: 24), 'Seats 40 · Assigned 24 · Free 16');
    expect(seatSummary(capacity: 40, assigned: 40), 'Seats 40 · Assigned 40 · Free 0');
    expect(seatSummary(capacity: 40, assigned: 43), 'Seats 40 · Assigned 43 · OVER by 3');
    expect(seatSummary(capacity: null, assigned: 5), '5 assigned · seat count not set');
  });

  group('reorderedStops', () {
    final stops = [_stop('A', 1), _stop('B', 2), _stop('C', 3)];

    test('moving a stop down swaps it with the next one', () {
      expect(reorderedStops(stops, 0, 1), {'A': 2, 'B': 1});
    });

    test('moving a stop up swaps it with the previous one', () {
      expect(reorderedStops(stops, 2, -1), {'C': 2, 'B': 3});
    });

    test('the first stop cannot go up and the last cannot go down', () {
      expect(reorderedStops(stops, 0, -1), isEmpty);
      expect(reorderedStops(stops, 2, 1), isEmpty);
    });

    test('gaps and duplicates in old data are repaired by renumbering 1..n', () {
      final messy = [_stop('A', 10), _stop('B', 10), _stop('C', 30)];
      final changes = reorderedStops(messy, 0, 1); // A and B swap
      expect(changes.values.toSet().length, changes.length);
      expect(changes.values.every((v) => v >= 1 && v <= 3), isTrue);
    });
  });

  test('stopsInTripOrder: ascending to campus, reversed from campus', () {
    final stops = [_stop('C', 3), _stop('A', 1), _stop('B', 2)];
    expect(stopsInTripOrder(stops, toCampus: true).map((s) => s.id), ['A', 'B', 'C']);
    expect(stopsInTripOrder(stops, toCampus: false).map((s) => s.id), ['C', 'B', 'A']);
  });

  group('transport models', () {
    test('BusInfo reads capacity and tolerates a bus without one', () {
      expect(BusInfo.fromMap('BUS-001', {'capacity': 40, 'driverUid': 'd1'}).capacity, 40);
      expect(BusInfo.fromMap('BUS-001', {}).capacity, isNull);
    });

    test('CampusLocation is null until both coordinates exist', () {
      expect(CampusLocation.fromMap(null), isNull);
      expect(CampusLocation.fromMap({'campusName': 'Main'}), isNull);
      final c = CampusLocation.fromMap({'campusName': 'CUI Attock', 'campusLat': 33.77, 'campusLng': 72.36});
      expect([c!.name, c.lat, c.lng], ['CUI Attock', 33.77, 72.36]);
    });

    test('trip direction ids round-trip', () {
      expect(TripDirectionX.fromId('toCampus'), TripDirection.toCampus);
      expect(TripDirection.fromCampus.id, 'fromCampus');
      expect(TripDirectionX.fromId('sideways'), isNull);
    });
  });
}
