import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_model.dart';
import '../models/dashboard_models.dart';
import 'student_providers.dart';

/// Whether a student's login is switched on (users/{uid}.active); null while
/// loading or if the account document is missing. Admin-only (firestore.rules).
final studentAccountActiveProvider = StreamProvider.autoDispose.family<bool?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? (d.data()?['active'] as bool? ?? false) : null);
});

/// A student's loans (current and returned), for the Admin overview.
final adminStudentLoansProvider = StreamProvider.autoDispose.family<List<LibraryIssueModel>, String>((ref, uid) {
  return ref.watch(studentRepositoryProvider).watchLibraryIssues(uid);
});

final adminStudentBusProvider = StreamProvider.autoDispose.family<BusAssignmentModel?, String>((ref, uid) {
  return ref.watch(studentRepositoryProvider).watchBusAssignment(uid);
});

/// Key for [adminStudentAttendanceProvider]: plain values, so the same course
/// reuses the same provider instance.
typedef StudentCourseKey = ({String uid, String courseId, String courseName});

final adminStudentAttendanceProvider =
    StreamProvider.autoDispose.family<CourseAttendanceSummary, StudentCourseKey>((ref, key) {
  return ref
      .watch(studentRepositoryProvider)
      .watchCourseAttendance(key.uid, CourseModel(id: key.courseId, name: key.courseName));
});
