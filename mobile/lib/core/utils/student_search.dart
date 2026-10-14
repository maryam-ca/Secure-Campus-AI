import '../../models/student_model.dart';

/// Minimum number of typed characters before a search runs.
const int studentSearchMinChars = 2;

/// Upper-cases and drops everything except letters and digits, so
/// "fa23-bse-007", "FA23 BSE 007" and "FA23BSE007" all compare equal.
String normalizeRegNo(String value) => value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Students whose registration number CONTAINS what was typed, or whose
/// NAME contains it (case, dashes and spaces ignored for the number; case
/// ignored for the name). Sorted by registration number.
///
/// Examples: "00" lists every student whose ID has "00" in it; "ayesh" lists
/// every student with "ayesh" in their name. The librarian then checks the
/// name and the complete ID and picks the right person, so nothing is
/// chosen automatically even when only one student matches.
///
/// Fewer than [studentSearchMinChars] characters returns nothing.
List<StudentModel> searchStudents(List<StudentModel> all, String query) {
  final text = query.trim().toLowerCase();
  final idQuery = normalizeRegNo(query);
  if (idQuery.length < studentSearchMinChars && text.length < studentSearchMinChars) return const [];

  final hits = all.where((s) {
    final idMatch = idQuery.length >= studentSearchMinChars && normalizeRegNo(s.registrationNumber).contains(idQuery);
    final nameMatch = text.length >= studentSearchMinChars && s.name.toLowerCase().contains(text);
    return idMatch || nameMatch;
  }).toList()
    ..sort((a, b) => a.registrationNumber.compareTo(b.registrationNumber));
  return hits;
}
