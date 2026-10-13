import 'package:cloud_firestore/cloud_firestore.dart';

/// Spec §30: shown as "Assigned" with stop, or "Not Assigned" - never a
/// live map (that's Admin/Driver only, §33).
class BusAssignmentModel {
  final String busId;
  final String stopId;
  final String stopName;

  const BusAssignmentModel({required this.busId, required this.stopId, required this.stopName});

  factory BusAssignmentModel.fromFirestore(Map<String, dynamic> data) {
    return BusAssignmentModel(
      busId: data['busId'] as String? ?? '',
      stopId: data['stopId'] as String? ?? '',
      stopName: data['stopName'] as String? ?? '',
    );
  }
}

enum LibraryIssueStatus { issued, overdue, returned }

class LibraryIssueModel {
  final String bookId;
  final String bookTitle;
  final DateTime issueDate;
  final DateTime expiryDate;
  final bool returned;

  const LibraryIssueModel({
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
      bookId: data['bookId'] as String? ?? '',
      bookTitle: data['bookTitle'] as String? ?? 'Unknown title',
      issueDate: (data['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      returned: data['returned'] as bool? ?? false,
    );
  }
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
