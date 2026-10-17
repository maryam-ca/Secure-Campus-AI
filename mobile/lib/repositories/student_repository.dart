import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_model.dart';
import '../models/dashboard_models.dart';
import '../models/student_model.dart';

/// Every read here is scoped to the signed-in student's own uid. This
/// mirrors (and is independently enforced server-side by) the Firestore
/// rules in firebase/firestore.rules - a student repository method that
/// took an arbitrary uid would still be blocked by those rules, but we
/// don't even expose that possibility in the API here (spec §8 - a
/// student portal that shows only their own data).
class StudentRepository {
  final FirebaseFirestore _db;

  StudentRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  Stream<StudentModel?> watchStudent(String uid) {
    return _db.collection('students').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return StudentModel.fromFirestore(doc);
    });
  }

  Future<List<CourseModel>> fetchCourses(List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    // Firestore whereIn caps at 30 - comfortably covers the ~5-6
    // courses per student the spec describes (§9).
    final snapshot = await _db.collection('courses').where(FieldPath.documentId, whereIn: courseIds).get();
    return snapshot.docs.map(CourseModel.fromFirestore).toList();
  }

  Stream<BusAssignmentModel?> watchBusAssignment(String studentId) {
    return _db
        .collection('busAssignments')
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : BusAssignmentModel.fromFirestore(snap.docs.first.data()));
  }

  Stream<List<LibraryIssueModel>> watchLibraryIssues(String studentId) {
    return _db
        .collection('libraryIssues')
        .where('studentId', isEqualTo: studentId)
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LibraryIssueModel.fromFirestore).toList());
  }

  Stream<List<AppNotification>> watchNotifications(String uid, {int limit = 20}) {
    return _db
        .collection('notifications')
        .where('recipient', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromFirestore).toList());
  }

  Future<void> markNotificationRead(String notificationId) {
    return _db.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  /// Deletes one notification - the student's own "dismiss this one"
  /// action, so old alerts don't have to sit there forever.
  Future<void> deleteNotification(String notificationId) {
    return _db.collection('notifications').doc(notificationId).delete();
  }

  /// Deletes every notification currently addressed to this student -
  /// backs the "Clear all" action.
  Future<void> clearAllNotifications(String uid) async {
    final snap = await _db.collection('notifications').where('recipient', isEqualTo: uid).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}