import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:intl/intl.dart';
import '../models/admin_models.dart';
import '../models/course_model.dart';
import '../models/student_model.dart';

/// Every read/write here maps 1:1 onto a real Firestore/RTDB call,
/// already permitted for the admin role by firebase/firestore.rules and
/// firebase/database.rules.json - nothing in this file is mocked, and
/// nothing here can succeed against an unconfigured Firebase project
/// (calls will simply throw, which the UI surfaces as a normal error
/// state - never a fabricated success).
class AdminRepository {
  final FirebaseFirestore _db;
  final FirebaseDatabase _rtdb;

  AdminRepository({FirebaseFirestore? firestore, FirebaseDatabase? database})
      : _db = firestore ?? FirebaseFirestore.instance,
        _rtdb = database ?? FirebaseDatabase.instance;

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  // ---------------------------------------------------------------
  // Dashboard (spec §41 - every figure is a real, live query)
  // ---------------------------------------------------------------
  Future<AdminDashboardStats> fetchDashboardStats({String busId = 'BUS-001'}) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final results = await Future.wait([
      _count(_db.collection('students')),
      _count(_db.collection('attendance').where('date', isEqualTo: todayStr)),
      _count(_db.collection('gateEntries')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))),
      _count(_db.collection('securityAlerts').where('status', isEqualTo: 'NEW')),
      _count(_db.collection('books')),
      _count(_db.collection('libraryIssues').where('returned', isEqualTo: false)),
      fetchBusStatus(busId),
    ]);

    return AdminDashboardStats(
      totalStudents: results[0] as int,
      todayAttendance: results[1] as int,
      todayGateEntries: results[2] as int,
      openUnknownAlerts: results[3] as int,
      totalBooks: results[4] as int,
      issuedBooks: results[5] as int,
      busStatus: results[6] as String,
    );
  }

  Future<String> fetchBusStatus(String busId) async {
    final snap = await _rtdb.ref('driverLocation/$busId').get();
    if (!snap.exists) return 'GPS UNAVAILABLE';
    final data = Map<String, dynamic>.from(snap.value as Map);
    return (data['tripActive'] as bool? ?? false) ? 'Trip Active' : 'Idle (last known location on file)';
  }

  /// Live driver location for the Admin map (spec §17/§34 - fixed after
  /// audit, see docs/AUDIT_REPORT.md "Not Implemented"/"Admin Live Bus
  /// Map"). Emits null when there is no location on file at all -
  /// callers must render "GPS UNAVAILABLE", never a fake/default pin.
  Stream<Map<String, dynamic>?> watchDriverLocation(String busId) {
    return _rtdb.ref('driverLocation/$busId').onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return Map<String, dynamic>.from(value as Map);
    });
  }

  // ---------------------------------------------------------------
  // Courses
  // ---------------------------------------------------------------
  Stream<List<AdminCourseModel>> watchCourses() {
    return _db.collection('courses').snapshots().map((s) => s.docs.map(AdminCourseModel.fromFirestore).toList());
  }

  Future<void> upsertCourse(AdminCourseModel course) {
    return _db.collection('courses').doc(course.id).set({
      'name': course.name,
      'cameraId': course.cameraId,
      'schedule': course.schedule.map((s) => s.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------
  // Books
  // ---------------------------------------------------------------
  Stream<List<BookModel>> watchBooks() {
    return _db.collection('books').orderBy(FieldPath.documentId).snapshots().map(
        (s) => s.docs.map(BookModel.fromFirestore).toList());
  }

  Future<void> upsertBook(String id, String title, String author, String category) {
    return _db.collection('books').doc(id).set({
      'title': title,
      'author': author,
      'category': category,
      'available': true,
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------
  // Bus / stops / assignments
  // ---------------------------------------------------------------
  Stream<List<BusStopModel>> watchBusStops() {
    return _db.collection('busStops').orderBy('order').snapshots().map(
        (s) => s.docs.map(BusStopModel.fromFirestore).toList());
  }

  Future<void> upsertBusStop(String id, String name, double lat, double lng, int order) {
    return _db.collection('busStops').doc(id).set({'name': name, 'lat': lat, 'lng': lng, 'order': order});
  }

  Stream<List<AdminBusAssignmentModel>> watchBusAssignments() {
    return _db.collection('busAssignments').snapshots().map(
        (s) => s.docs.map(AdminBusAssignmentModel.fromFirestore).toList());
  }

  /// Denormalizes studentName/stopName onto the assignment doc itself so
  /// the Student portal (and the bus_eta job) can read them without an
  /// extra join - see mobile/lib/repositories/student_repository.dart.
  Future<void> assignStudentToBus({
    required String studentId,
    required String studentName,
    required String busId,
    required String stopId,
    required String stopName,
  }) {
    return _db.collection('busAssignments').doc(studentId).set({
      'studentId': studentId,
      'studentName': studentName,
      'busId': busId,
      'stopId': stopId,
      'stopName': stopName,
    });
  }

  Future<void> removeBusAssignment(String assignmentId) {
    return _db.collection('busAssignments').doc(assignmentId).delete();
  }

  // ---------------------------------------------------------------
  // Accounts (creation itself goes through BackendApiService - Admin
  // SDK only; everything else here is a plain, rules-permitted read/write)
  // ---------------------------------------------------------------
  Stream<List<AccountSummary>> watchAccountsByRole(String role) {
    return _db.collection('users').where('role', isEqualTo: role).snapshots().map(
        (s) => s.docs.map(AccountSummary.fromFirestore).toList());
  }

  Stream<List<StudentModel>> watchAllStudents() {
    return _db.collection('students').orderBy('registrationNumber').snapshots().map(
        (s) => s.docs.map(StudentModel.fromFirestore).toList());
  }

  Future<void> setAccountActive(String uid, bool active) {
    return _db.collection('users').doc(uid).update({'active': active});
  }

  Future<void> updateStudent(String uid, {String? program, int? semester, List<String>? courses}) {
    final update = <String, dynamic>{};
    if (program != null) update['program'] = program;
    if (semester != null) update['semester'] = semester;
    if (courses != null) update['courses'] = courses;
    return _db.collection('students').doc(uid).update(update);
  }

  Future<List<CourseModel>> fetchAllCourseOptions() async {
    final snap = await _db.collection('courses').get();
    return snap.docs.map(CourseModel.fromFirestore).toList();
  }

  // ---------------------------------------------------------------
  // Gate entries / security alerts (Admin's read-only oversight view -
  // Security has its own portal for day-to-day handling)
  // ---------------------------------------------------------------
  Stream<List<GateEntryModel>> watchRecentGateEntries({int limit = 50}) {
    return _db.collection('gateEntries').orderBy('timestamp', descending: true).limit(limit).snapshots().map(
        (s) => s.docs.map(GateEntryModel.fromFirestore).toList());
  }

  Stream<List<SecurityAlertModel>> watchSecurityAlerts({int limit = 50}) {
    return _db.collection('securityAlerts').orderBy('createdAt', descending: true).limit(limit).snapshots().map(
        (s) => s.docs.map(SecurityAlertModel.fromFirestore).toList());
  }

  Future<void> setAlertStatus(String alertId, bool resolved) {
    return _db.collection('securityAlerts').doc(alertId).update({'status': resolved ? 'RESOLVED' : 'NEW'});
  }

  // ---------------------------------------------------------------
  // Lost card reports
  // ---------------------------------------------------------------
  Stream<List<LostCardReportModel>> watchLostCardReports() {
    return _db.collection('lostCardReports').orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map(LostCardReportModel.fromFirestore).toList());
  }

  /// Finds a student by registration number and sends them the
  /// found-card notification (spec §23 - informational Rs.100 fine
  /// note, no payment record of any kind).
  Future<bool> notifyStudentCardFound(LostCardReportModel report) async {
    if (report.registrationNumberGuess.isEmpty) return false;

    final match = await _db
        .collection('students')
        .where('registrationNumber', isEqualTo: report.registrationNumberGuess)
        .limit(1)
        .get();
    if (match.docs.isEmpty) return false;

    final studentId = match.docs.first.id;
    await _db.collection('notifications').add({
      'recipient': studentId,
      'title': 'Student Card Found',
      'message': 'Your student card has been found at "${report.location}". '
          'Please collect it from Admin. Fine: Rs. 100 (informational only - no online payment).',
      'type': 'LOST_CARD',
      'isRead': false,
      'metadata': {'reportId': report.id},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('lostCardReports').doc(report.id).update({'notified': true});
    return true;
  }
}
