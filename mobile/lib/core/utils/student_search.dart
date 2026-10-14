import '../../models/student_model.dart';

/// Minimum number of typed characters before a search runs
/// (the librarian can type just the last three digits, e.g. "007").
const int studentSearchMinChars = 3;

/// Upper-cases and drops everything except letters and digits, so
/// "fa23-bse-007", "FA23 BSE 007" and "FA23BSE007" all compare equal.
String normalizeRegNo(String value) => value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Students whose registration number ENDS WITH what was typed
/// (case, dashes and spaces ignored), sorted by registration number.
///
/// Typing the last three digits is enough. When two intakes share the same
/// ending (FA23-BSE-007 and FA22-BSE-007) both are returned so the librarian
/// can pick the right one. Fewer than [studentSearchMinChars] characters
/// returns nothing, so a single digit never lists half the campus.
List<StudentModel> searchStudentsByRegNo(List<StudentModel> all, String query) {
  final q = normalizeRegNo(query);
  if (q.length < studentSearchMinChars) return const [];
  final hits = all.where((s) => normalizeRegNo(s.registrationNumber).endsWith(q)).toList()
    ..sort((a, b) => a.registrationNumber.compareTo(b.registrationNumber));
  return hits;
}
