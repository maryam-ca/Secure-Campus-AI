import '../../models/student_model.dart';
import 'student_search.dart';

enum IrisFilter { all, enrolled, notEnrolled }

/// Students for the Admin list: narrowed by what was typed, by iris status and
/// by semester. Sorted by registration number.
///
/// The text matches any part of the name, program or email, and any part of the
/// registration number (case, dashes and spaces ignored: `007` or `bse-00`).
List<StudentModel> filterStudents(
  List<StudentModel> all, {
  String query = '',
  IrisFilter iris = IrisFilter.all,
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

  bool irisHit(StudentModel s) {
    switch (iris) {
      case IrisFilter.all:
        return true;
      case IrisFilter.enrolled:
        return s.irisEnrolled;
      case IrisFilter.notEnrolled:
        return !s.irisEnrolled;
    }
  }

  return all.where((s) => textHit(s) && irisHit(s) && (semester == null || s.semester == semester)).toList()
    ..sort((a, b) => a.registrationNumber.compareTo(b.registrationNumber));
}

/// How many students fall in each iris group (shown on the filter chips).
({int all, int enrolled, int notEnrolled}) irisCounts(List<StudentModel> students) {
  final enrolled = students.where((s) => s.irisEnrolled).length;
  return (all: students.length, enrolled: enrolled, notEnrolled: students.length - enrolled);
}

/// The semesters that actually occur, ascending (for the semester filter).
List<int> semestersIn(List<StudentModel> students) => (students.map((s) => s.semester).toSet().toList()..sort());
