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

  /// Writes one real GPS fix. `tripId` stays constant for the duration
  /// of a trip so the bus_eta job can dedupe "already alerted this
  /// student for this trip" (see bus_eta/app/service.py).
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
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'tripActive': tripActive,
      'tripId': tripId,
    });
  }

  Future<void> markTripStopped({required String busId, required String tripId}) {
    return _rtdb.ref('driverLocation/$busId').update({
      'tripActive': false,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
