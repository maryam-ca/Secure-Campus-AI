import 'package:cloud_firestore/cloud_firestore.dart';

/// A student's "I did not borrow this book" report (proposal 4.2:
/// students can report unauthorized issues, alerting librarian + security).
class IssueReportModel {
  static const statusNew = 'NEW';
  static const statusResolved = 'RESOLVED';

  final String id;
  final String issueId;
  final String bookId;
  final String bookTitle;
  final String studentId;
  final String studentName;
  final String registrationNumber;
  final String note;
  final String status;
  final DateTime? createdAt;

  const IssueReportModel({
    required this.id,
    required this.issueId,
    required this.bookId,
    required this.bookTitle,
    required this.studentId,
    required this.studentName,
    required this.registrationNumber,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  bool get isOpen => status != statusResolved;

  factory IssueReportModel.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return IssueReportModel(
      id: id,
      issueId: data['issueId'] as String? ?? '',
      bookId: data['bookId'] as String? ?? '',
      bookTitle: data['bookTitle'] as String? ?? 'Unknown title',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      registrationNumber: data['registrationNumber'] as String? ?? '',
      note: data['note'] as String? ?? '',
      status: data['status'] as String? ?? statusNew,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  factory IssueReportModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      IssueReportModel.fromMap(doc.id, doc.data() ?? {});
}
