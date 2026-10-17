import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../models/course_model.dart';
import '../models/student_model.dart';
import '../models/transport_models.dart';
import '../repositories/admin_repository.dart';
import '../services/backend_api_service.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());
final backendApiServiceProvider = Provider<BackendApiService>((ref) => BackendApiService());

/// One-shot aggregate read (uses Firestore count() queries), refreshed
/// via pull-to-refresh (ref.invalidate) rather than held open as a
/// continuous stream - a dashboard doesn't need per-second updates, and
/// this keeps read costs sane (spec §41 only requires "real", not
/// "sub-second live").
final dashboardStatsProvider = FutureProvider.autoDispose<AdminDashboardStats>((ref) {
  return ref.watch(adminRepositoryProvider).fetchDashboardStats();
});

final coursesProvider = StreamProvider.autoDispose<List<AdminCourseModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchCourses();
});

final courseOptionsProvider = FutureProvider.autoDispose<List<CourseModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAllCourseOptions();
});

final booksProvider = StreamProvider.autoDispose<List<BookModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchBooks();
});

final busStopsProvider = StreamProvider.autoDispose<List<BusStopModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchBusStops();
});

final busAssignmentsProvider = StreamProvider.autoDispose<List<AdminBusAssignmentModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchBusAssignments();
});

final busInfoProvider = StreamProvider.autoDispose.family<BusInfo, String>((ref, busId) {
  return ref.watch(adminRepositoryProvider).watchBus(busId);
});

final campusLocationProvider = StreamProvider.autoDispose<CampusLocation?>((ref) {
  return ref.watch(adminRepositoryProvider).watchCampus();
});

/// Live driver GPS for the Admin map - see admin_bus_screen.dart.
final driverLocationProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, busId) {
  return ref.watch(adminRepositoryProvider).watchDriverLocation(busId);
});

final allStudentsProvider = StreamProvider.autoDispose<List<StudentModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllStudents();
});

final accountsByRoleProvider = StreamProvider.family.autoDispose<List<AccountSummary>, String>((ref, role) {
  return ref.watch(adminRepositoryProvider).watchAccountsByRole(role);
});

final gateEntriesProvider = StreamProvider.autoDispose<List<GateEntryModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchRecentGateEntries();
});

final securityAlertsProvider = StreamProvider.autoDispose<List<SecurityAlertModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchSecurityAlerts();
});

final lostCardReportsProvider = StreamProvider.autoDispose<List<LostCardReportModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchLostCardReports();
});

/// The registered student's name for a registration number (null: no such
/// student), so Admin can check a finder's report against the real record.
final registeredNameProvider = FutureProvider.autoDispose.family<String?, String>((ref, regNo) {
  return ref.watch(adminRepositoryProvider).registeredStudentName(regNo);
});

/// Reports Security should see: open ones, plus resolved ones for a day.
final securityLostCardsProvider = Provider.autoDispose<AsyncValue<List<LostCardReportModel>>>((ref) {
  final now = DateTime.now();
  return ref.watch(lostCardReportsProvider).whenData((all) => all.where((r) => r.visibleToSecurity(now)).toList());
});
