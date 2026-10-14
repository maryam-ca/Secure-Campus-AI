/// The bus itself: how many seats it has (set by the Admin).
class BusInfo {
  final String id;

  /// Seating capacity; null until the Admin sets it.
  final int? capacity;
  final String? driverUid;

  const BusInfo({required this.id, this.capacity, this.driverUid});

  factory BusInfo.fromMap(String id, Map<String, dynamic> data) => BusInfo(
        id: id,
        capacity: (data['capacity'] as num?)?.toInt(),
        driverUid: data['driverUid'] as String?,
      );
}

/// Where the campus is: the destination of the morning trip and the start of
/// the afternoon trip. Set once by the Admin (Firestore `config/transport`).
class CampusLocation {
  final String name;
  final double lat;
  final double lng;

  const CampusLocation({required this.name, required this.lat, required this.lng});

  /// Null when the Admin has not set the campus yet.
  static CampusLocation? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final lat = (data['campusLat'] as num?)?.toDouble();
    final lng = (data['campusLng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return CampusLocation(name: data['campusName'] as String? ?? 'Campus', lat: lat, lng: lng);
  }
}

/// Which way a trip runs.
enum TripDirection { toCampus, fromCampus }

extension TripDirectionX on TripDirection {
  /// Stored in Firestore / read by the bus_eta service.
  String get id => this == TripDirection.toCampus ? 'toCampus' : 'fromCampus';

  String get label => this == TripDirection.toCampus ? 'To campus' : 'From campus';

  static TripDirection? fromId(String? id) {
    for (final d in TripDirection.values) {
      if (d.id == id) return d;
    }
    return null;
  }
}
