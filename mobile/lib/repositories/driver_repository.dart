import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;

class DriverRepository {
  final FirebaseFirestore _db;
  final FirebaseDatabase _rtdb;

  DriverRepository({FirebaseFirestore? firestore, FirebaseDatabase? database})
      : _db = firestore ?? FirebaseFirestore.instance,
        _rtdb = database ?? FirebaseDatabase.instance;

  /// Looks up which bus (if any) this driver is actually assigned to -
  /// never assumes "BUS-001", so the UI can say plainly if a driver
  /// account exists without an assignment yet.
  Future<String?> fetchAssignedBusId(String driverUid) async {
    final snap = await _db.collection('bus').where('driverUid', isEqualTo: driverUid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// True when the database still says a trip is running for this bus, for
  /// example because the app was killed during the last trip.
  Future<bool> isTripMarkedActive(String busId) async {
    final snap = await _rtdb.ref('driverLocation/$busId/tripActive').get();
    return snap.exists && snap.value == true;
  }

  /// Asks the DATABASE SERVER to mark the trip ended if this phone drops off
  /// (app killed, phone off, no signal). Without this a dead driver phone
  /// would look live. Call when a trip starts; cancel on a clean stop.
  Future<void> armAutoEnd(String busId) {
    return _rtdb.ref('driverLocation/$busId').onDisconnect().update({
      'tripActive': false,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> cancelAutoEnd(String busId) {
    return _rtdb.ref('driverLocation/$busId').onDisconnect().cancel();
  }

  /// Writes one real GPS fix. `tripId` stays constant for the duration
  /// of a trip so the bus_eta job can dedupe "already alerted this
  /// student for this trip" (see bus_eta/app/service.py).
  ///
  /// `updatedAt` is the database SERVER's clock, so a wrong clock on the
  /// driver's phone cannot make an old location look fresh (or a fresh one
  /// look old) to the bus_eta service.
  Future<void> pushLocation({
    required String busId,
    required double lat,
    required double lng,
    required bool tripActive,
    required String tripId,
  }) {
    return _rtdb.ref('driverLocation/$busId').set({
      'lat': lat,
      'lng': lng,
      'updatedAt': ServerValue.timestamp,
      'tripActive': tripActive,
      'tripId': tripId,
    });
  }

  Future<void> markTripStopped({required String busId, required String tripId}) async {
    await _rtdb.ref('driverLocation/$busId').update({
      'tripActive': false,
      'updatedAt': ServerValue.timestamp,
    });
    await cancelAutoEnd(busId);
  }
}
