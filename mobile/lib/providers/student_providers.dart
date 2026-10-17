import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_model.dart';
import '../models/dashboard_models.dart';
import '../models/student_model.dart';
import '../repositories/student_repository.dart';
import 'auth_provider.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) => StudentRepository());

/// Null while loading/signed-out; never another student's data (uid
/// comes only from the authenticated session, never a parameter the UI
/// could supply arbitrarily).
final studentProfileProvider = StreamProvider<StudentModel?>((ref) {
  final appUser = ref.watch(currentAppUserProvider).value;
  if (appUser == null) return Stream.value(null);
  return ref.watch(studentRepositoryProvider).watchStudent(appUser.uid);
});

final studentCoursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  final student = ref.watch(studentProfileProvider).value;
  if (student == null || student.courseIds.isEmpty) return [];
  return ref.watch(studentRepositoryProvider).fetchCourses(student.courseIds);
});

final busAssignmentProvider = StreamProvider<BusAssignmentModel?>((ref) {
  final student = ref.watch(studentProfileProvider).value;
  if (student == null) return Stream.value(null);
  return ref.watch(studentRepositoryProvider).watchBusAssignment(student.uid);
});

final libraryIssuesProvider = StreamProvider<List<LibraryIssueModel>>((ref) {
  final student = ref.watch(studentProfileProvider).value;
  if (student == null) return Stream.value(const []);
  return ref.watch(studentRepositoryProvider).watchLibraryIssues(student.uid);
});

final studentNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final appUser = ref.watch(currentAppUserProvider).value;
  if (appUser == null) return Stream.value(const []);
  return ref.watch(studentRepositoryProvider).watchNotifications(appUser.uid);
});

/// Alerts the student has not opened yet (drives the badge on the Alerts tab).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(studentNotificationsProvider).valueOrNull ?? const <AppNotification>[];
  return list.where((n) => !n.isRead).length;
});
