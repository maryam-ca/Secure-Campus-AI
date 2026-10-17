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
