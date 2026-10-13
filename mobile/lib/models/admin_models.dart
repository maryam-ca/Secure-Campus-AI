import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleSlot {
  final String dayOfWeek; // "Monday".."Sunday"
  final String startTime; // "HH:MM" 24h
  final String endTime;

  const ScheduleSlot({required this.dayOfWeek, required this.startTime, required this.endTime});

  Map<String, dynamic> toMap() => {'dayOfWeek': dayOfWeek, 'startTime': startTime, 'endTime': endTime};

  factory ScheduleSlot.fromMap(Map<String, dynamic> map) => ScheduleSlot(
        dayOfWeek: map['dayOfWeek'] as String? ?? 'Monday',
        startTime: map['startTime'] as String? ?? '09:00',
        endTime: map['endTime'] as String? ?? '10:00',
      );
}

class AdminCourseModel {
  final String id;
  final String name;
  final String cameraId;
  final List<ScheduleSlot> schedule;

  const AdminCourseModel({required this.id, required this.name, required this.cameraId, required this.schedule});

  factory AdminCourseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminCourseModel(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      cameraId: data['cameraId'] as String? ?? '',
      schedule: (data['schedule'] as List? ?? const [])
          .map((s) => ScheduleSlot.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class BookModel {
  final String id;
  final String title;
  final String author;
  final String category;
  final bool available;

  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.available,
  });

  factory BookModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BookModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      category: data['category'] as String? ?? '',
      available: data['available'] as bool? ?? true,
    );
  }
}

class GateEntryModel {
  final String id;
  final String studentId;
  final String registrationNumber;
  final String name;
  final double recognitionScore;
  final String cameraLocation;
  final DateTime? timestamp;

  const GateEntryModel({
    required this.id,
    required this.studentId,
    required this.registrationNumber,
    required this.name,
    required this.recognitionScore,
    required this.cameraLocation,
    required this.timestamp,
  });

  factory GateEntryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GateEntryModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      registrationNumber: data['registrationNumber'] as String? ?? '',
      name: data['name'] as String? ?? '',
      recognitionScore: (data['recognitionScore'] as num?)?.toDouble() ?? 0.0,
      cameraLocation: data['cameraLocation'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

enum SecurityAlertStatus { newAlert, resolved }

class SecurityAlertModel {
  final String id;
  final String cameraLocation;
  final String imagePath;
  final double bestMatchScore;
  final SecurityAlertStatus status;
  final DateTime? createdAt;

  const SecurityAlertModel({
    required this.id,
    required this.cameraLocation,
    required this.imagePath,
    required this.bestMatchScore,
    required this.status,
    required this.createdAt,
  });

  factory SecurityAlertModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr = data['status'] as String? ?? 'NEW';
    return SecurityAlertModel(
      id: doc.id,
      cameraLocation: data['cameraLocation'] as String? ?? '',
      // Deliberately a Storage *path*, not a public URL (fixed post-audit
      // - see docs/AUDIT_REPORT.md "Security Issues" #1). The viewing URL
      // is obtained live via FirebaseStorage.ref(imagePath).getDownloadURL(),
      // which storage.rules actually gates to admin/security per call.
      imagePath: data['imagePath'] as String? ?? '',
      bestMatchScore: (data['bestMatchScore'] as num?)?.toDouble() ?? 0.0,
      status: statusStr == 'RESOLVED' ? SecurityAlertStatus.resolved : SecurityAlertStatus.newAlert,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class LostCardReportModel {
  final String id;
  final String studentNameGuess;
  final String registrationNumberGuess;
  final String location;
  final String description;
  final bool notified;
  final DateTime? createdAt;

  const LostCardReportModel({
    required this.id,
    required this.studentNameGuess,
    required this.registrationNumberGuess,
    required this.location,
    required this.description,
    required this.notified,
    required this.createdAt,
  });

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
  final int todayAttendance;
  final int todayGateEntries;
  final int openUnknownAlerts;
  final int totalBooks;
  final int issuedBooks;
  final String busStatus; // "Trip Active" | "Idle" | "GPS Unavailable"

  const AdminDashboardStats({
    required this.totalStudents,
    required this.todayAttendance,
    required this.todayGateEntries,
    required this.openUnknownAlerts,
    required this.totalBooks,
    required this.issuedBooks,
    required this.busStatus,
  });
}
