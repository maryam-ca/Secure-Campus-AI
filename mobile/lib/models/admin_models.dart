import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCourseModel {
  final String id;
  final String name;

  const AdminCourseModel({required this.id, required this.name});

  factory AdminCourseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminCourseModel(id: doc.id, name: data['name'] as String? ?? doc.id);
  }
}

class BookModel {
  final String id;
  final String title;
  final String author;
  final String category;
  final bool available;

  /// A locked book is kept physically in the safe and cannot be issued.
  /// Only a book that has been received (returned) can be locked.
  final bool locked;
  final String lockReason;
  final String lockedByName;
  final DateTime? lockedAt;

  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.available,
    this.locked = false,
    this.lockReason = '',
    this.lockedByName = '',
    this.lockedAt,
  });

  factory BookModel.fromMap(String id, Map<String, dynamic> data) {
    final lockedAt = data['lockedAt'];
    return BookModel(
      id: id,
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      category: data['category'] as String? ?? '',
      available: data['available'] as bool? ?? true,
      locked: data['locked'] as bool? ?? false,
      lockReason: data['lockReason'] as String? ?? '',
      lockedByName: data['lockedByName'] as String? ?? '',
      lockedAt: lockedAt is Timestamp ? lockedAt.toDate() : null,
    );
  }

  factory BookModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      BookModel.fromMap(doc.id, doc.data() ?? {});
}

/// One entry in a book's lock history (books/{id}/lockHistory): who locked or
/// unlocked it, in which role, when, and the reason they gave.
class BookLockEvent {
  static const lockAction = 'LOCK';
  static const unlockAction = 'UNLOCK';

  final String id;
  final String action; // LOCK | UNLOCK
  final String reason;
  final String byUid;
  final String byName;
  final String byRole;
  final DateTime? at;

  const BookLockEvent({
    required this.id,
    required this.action,
    required this.reason,
    required this.byUid,
    required this.byName,
    required this.byRole,
    required this.at,
  });

  bool get isLock => action == lockAction;

  factory BookLockEvent.fromMap(String id, Map<String, dynamic> data) {
    final at = data['at'];
    return BookLockEvent(
      id: id,
      action: data['action'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      byUid: data['byUid'] as String? ?? '',
      byName: data['byName'] as String? ?? '',
      byRole: data['byRole'] as String? ?? '',
      at: at is Timestamp ? at.toDate() : null,
    );
  }

  factory BookLockEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      BookLockEvent.fromMap(doc.id, doc.data() ?? {});
}

class LostCardReportModel {
  final String id;
  final String studentNameGuess;
  final String registrationNumberGuess;
  final String location;
  final String description;
  final bool notified;
  final DateTime? createdAt;

  /// 'OPEN' until an Admin resolves it, then 'RESOLVED' (Admin only).
  final String status;
  final DateTime? resolvedAt;

  /// The finder attached a photo of the card (kept in `lostCardPhotos`, which
  /// only Admin can read).
  final bool hasPhoto;

  const LostCardReportModel({
    required this.id,
    required this.studentNameGuess,
    required this.registrationNumberGuess,
    required this.location,
    required this.description,
    required this.notified,
    required this.createdAt,
    this.status = 'OPEN',
    this.resolvedAt,
    this.hasPhoto = false,
  });

  bool get isResolved => status == 'RESOLVED';

  /// Security keeps seeing a resolved report, marked Resolved, for this long
  /// and then it disappears from their list.
  static const securityResolvedVisibility = Duration(hours: 24);

  /// Whether Security should still list this report at [now]: open ones always,
  /// resolved ones only for [securityResolvedVisibility] after resolving.
  bool visibleToSecurity(DateTime now) {
    if (!isResolved) return true;
    final at = resolvedAt;
    return at != null && now.difference(at) < securityResolvedVisibility;
  }

  factory LostCardReportModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LostCardReportModel(
      id: doc.id,
      studentNameGuess: data['studentName'] as String? ?? '',
      registrationNumberGuess: data['registrationNumber'] as String? ?? '',
      location: data['location'] as String? ?? '',
      description: data['description'] as String? ?? '',
      notified: data['notified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'OPEN',
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      hasPhoto: data['hasPhoto'] as bool? ?? false,
    );
  }
}

class BusStopModel {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int order;

  const BusStopModel({required this.id, required this.name, required this.lat, required this.lng, required this.order});

  factory BusStopModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BusStopModel(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminBusAssignmentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String stopId;
  final String stopName;

  const AdminBusAssignmentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.stopId,
    required this.stopName,
  });

  factory AdminBusAssignmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminBusAssignmentModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      stopId: data['stopId'] as String? ?? '',
      stopName: data['stopName'] as String? ?? '',
    );
  }
}

/// A row in an account-management list (students/security/librarian/driver).
class AccountSummary {
  final String uid;
  final String name;
  final String email;
  final bool active;

  const AccountSummary({required this.uid, required this.name, required this.email, required this.active});

  factory AccountSummary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AccountSummary(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      active: data['active'] as bool? ?? false,
    );
  }
}

/// A row in the Librarian's "currently issued" list - the superset of
/// dashboard_models.dart's student-facing LibraryIssueModel, with the
/// borrower's identity attached (spec §26 - librarian's own view).
class LibrarianIssueRow {
  final String id;
  final String bookId;
  final String bookTitle;
  final String studentId;
  final String studentName;
  final String registrationNumber;
  final DateTime issueDate;
  final DateTime expiryDate;
  final bool returned;

  const LibrarianIssueRow({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.studentId,
    required this.studentName,
    required this.registrationNumber,
    required this.issueDate,
    required this.expiryDate,
    required this.returned,
  });

  bool get isOverdue => !returned && DateTime.now().isAfter(expiryDate);

  factory LibrarianIssueRow.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LibrarianIssueRow(
      id: doc.id,
      bookId: data['bookId'] as String? ?? '',
      bookTitle: data['bookTitle'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      registrationNumber: data['registrationNumber'] as String? ?? '',
      issueDate: (data['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      returned: data['returned'] as bool? ?? false,
    );
  }
}

/// Real-time, always-computed dashboard counters (spec §41 - never
/// hardcoded). Each field is populated by its own live Firestore/RTDB
/// query in admin_repository.dart / admin_providers.dart.
class AdminDashboardStats {
  final int totalStudents;
  final int totalBooks;
  final int issuedBooks;
  final String busStatus; // "Trip Active" | "Idle" | "GPS Unavailable"

  const AdminDashboardStats({
    required this.totalStudents,
    required this.totalBooks,
    required this.issuedBooks,
    required this.busStatus,
  });
}
