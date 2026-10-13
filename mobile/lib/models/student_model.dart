import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String uid;
  final String registrationNumber;
  final String name;
  final String program;
  final int semester;
  final String email;
  final List<String> courseIds;
  final bool irisEnrolled;

  const StudentModel({
    required this.uid,
    required this.registrationNumber,
    required this.name,
    required this.program,
    required this.semester,
    required this.email,
    required this.courseIds,
    required this.irisEnrolled,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudentModel(
      uid: doc.id,
      registrationNumber: data['registrationNumber'] as String? ?? '',
      name: data['name'] as String? ?? '',
      program: data['program'] as String? ?? '',
      semester: (data['semester'] as num?)?.toInt() ?? 0,
      email: data['email'] as String? ?? '',
      courseIds: List<String>.from(data['courses'] as List? ?? const []),
      irisEnrolled: data['irisEnrolled'] as bool? ?? false,
    );
  }
}
