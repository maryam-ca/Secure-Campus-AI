import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dashboard_models.dart';
import '../models/issue_report_model.dart';
import '../models/student_model.dart';

class IssueReportRepository {
  final FirebaseFirestore _db;
  IssueReportRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  /// Student side. firestore.rules checks that the issue really belongs to
  /// the signed-in student, so a report cannot be filed against someone
  /// else's loan.
  Future<void> submit({
    required LibraryIssueModel issue,
    required StudentModel student,
    String note = '',
  }) {
    return _db.collection('issueReports').add({
      'issueId': issue.id,
      'bookId': issue.bookId,
      'bookTitle': issue.bookTitle,
      'studentId': student.uid,
      'studentName': student.name,
      'registrationNumber': student.registrationNumber,
      'note': note.trim(),
      'status': IssueReportModel.statusNew,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Staff side (Librarian / Security / Admin), newest first.
  Stream<List<IssueReportModel>> watchAll() {
    return _db
        .collection('issueReports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(IssueReportModel.fromFirestore).toList());
  }

  Future<void> setResolved(String reportId, {required bool resolved}) {
    return _db.collection('issueReports').doc(reportId).update({
      'status': resolved ? IssueReportModel.statusResolved : IssueReportModel.statusNew,
    });
  }
}
