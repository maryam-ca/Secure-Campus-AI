import 'package:cloud_firestore/cloud_firestore.dart';

/// How urgent the student's bus status is (drives the colour on screen).
enum BusTripLevel { idle, onTheWay, getReady, headOut }

class BusTripInfo {
  final BusTripLevel level;
  final String text;
  const BusTripInfo(this.level, this.text);
}

/// Spec §30: shown as "Assigned" with stop, or "Not Assigned" - never a
/// live map (that's Admin/Driver only, §33). The bus_eta service writes a small
/// text-only status (is a trip running, about how many minutes from this
/// stop) onto the student's own assignment so no location is exposed.
class BusAssignmentModel {
  /// A status older than this is treated as stale (the service stopped).
  static const staleAfter = Duration(minutes: 3);

  /// Same thresholds the service uses for its two reminders.
  static const getReadyMinutes = 20;
  static const headOutMinutes = 10;

  final String busId;
  final String stopId;
  final String stopName;
  final bool tripActive;
  final int? etaMinutes;
  final DateTime? statusUpdatedAt;

  const BusAssignmentModel({
    required this.busId,
    required this.stopId,
    required this.stopName,
    this.tripActive = false,
    this.etaMinutes,
    this.statusUpdatedAt,
  });

  factory BusAssignmentModel.fromFirestore(Map<String, dynamic> data) {
    final updated = data['statusUpdatedAt'];
    return BusAssignmentModel(
      busId: data['busId'] as String? ?? '',
      stopId: data['stopId'] as String? ?? '',
      stopName: data['stopName'] as String? ?? '',
      tripActive: data['tripActive'] == true,
      etaMinutes: (data['etaMinutes'] as num?)?.toInt(),
      statusUpdatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  /// What to tell the student right now, in words.
  BusTripInfo tripInfo(DateTime now) {
    final updated = statusUpdatedAt;
    final eta = etaMinutes;
    final fresh = updated != null && now.difference(updated) <= staleAfter;
    if (!tripActive || !fresh || eta == null) {
      return const BusTripInfo(BusTripLevel.idle, 'No trip in progress right now.');
    }
    if (eta <= 1) return const BusTripInfo(BusTripLevel.headOut, 'Your bus is arriving now.');
    if (eta <= headOutMinutes) {
      return BusTripInfo(BusTripLevel.headOut, 'About $eta min from your stop - head to your pickup point now.');
    }
    if (eta <= getReadyMinutes) {
      return BusTripInfo(BusTripLevel.getReady, 'About $eta min from your stop - get ready.');
    }
    return BusTripInfo(BusTripLevel.onTheWay, 'On its way - about $eta min from your stop.');
  }
}

enum LibraryIssueStatus { issued, overdue, returned }

class LibraryIssueModel {
  /// libraryIssues document id ('' when built outside Firestore, e.g. in tests).
  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime issueDate;
  final DateTime expiryDate;
  final bool returned;
  final DateTime? returnedAt;

  const LibraryIssueModel({
    this.returnedAt,
    this.id = '',
    required this.bookId,
    required this.bookTitle,
    required this.issueDate,
    required this.expiryDate,
    required this.returned,
  });

  /// Computed live against the current date (spec §28) - never a stored
  /// "OVERDUE" flag that could go stale.
  LibraryIssueStatus get status {
    if (returned) return LibraryIssueStatus.returned;
    return DateTime.now().isAfter(expiryDate) ? LibraryIssueStatus.overdue : LibraryIssueStatus.issued;
  }

  factory LibraryIssueModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LibraryIssueModel(
      id: doc.id,
      bookId: data['bookId'] as String? ?? '',
      bookTitle: data['bookTitle'] as String? ?? 'Unknown title',
      issueDate: (data['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      returned: data['returned'] as bool? ?? false,
      returnedAt: (data['returnedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Whole days from [now] until the due date (negative once overdue).
  int daysUntilDue(DateTime now) =>
      DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'SYSTEM',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
