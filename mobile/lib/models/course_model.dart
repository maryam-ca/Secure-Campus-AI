import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String name;

  const CourseModel({required this.id, required this.name});

  factory CourseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CourseModel(id: doc.id, name: data['name'] as String? ?? doc.id);
  }
}

/// Computed entirely from real `attendance` documents at read time -
/// never a stored/hardcoded percentage (spec §17).
class CourseAttendanceSummary {
  final CourseModel course;
  final int totalSessions;
  final int present;

  const CourseAttendanceSummary({
    required this.course,
    required this.totalSessions,
    required this.present,
  });

  int get absent => totalSessions - present;

  double get percentage => totalSessions == 0 ? 0.0 : (present / totalSessions) * 100.0;
}
