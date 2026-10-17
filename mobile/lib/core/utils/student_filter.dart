import '../../models/student_model.dart';
import 'student_search.dart';

/// Students for the Admin list: narrowed by what was typed and
/// by semester. Sorted by registration number.
///
/// The text matches any part of the name, program or email, and any part of the
/// registration number (case, dashes and spaces ignored: `007` or `bse-00`).
List<StudentModel> filterStudents(
  List<StudentModel> all, {
  String query = '',
  int? semester,
}) {
  final text = query.trim().toLowerCase();
  final id = normalizeRegNo(query);

  bool textHit(StudentModel s) {
    if (text.isEmpty) return true;
    return s.name.toLowerCase().contains(text) ||
        s.program.toLowerCase().contains(text) ||
        s.email.toLowerCase().contains(text) ||
        s.registrationNumber.toLowerCase().contains(text) ||
        (id.isNotEmpty && normalizeRegNo(s.registrationNumber).contains(id));
  }


  return all.where((s) => textHit(s) && (semester == null || s.semester == semester)).toList()
    ..sort((a, b) => a.registrationNumber.compareTo(b.registrationNumber));
}


/// The semesters that actually occur, ascending (for the semester filter).
List<int> semestersIn(List<StudentModel> students) => (students.map((s) => s.semester).toSet().toList()..sort());
