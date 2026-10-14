import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/student_search.dart';
import 'package:securecampus/models/student_model.dart';

StudentModel _s(String reg, String name) => StudentModel(
      uid: 'uid-$reg',
      registrationNumber: reg,
      name: name,
      program: 'BSE',
      semester: 5,
      email: '$reg@x.edu',
      courseIds: const [],
      irisEnrolled: false,
    );

final _students = [
  _s('FA23-BSE-001', 'Ayesha Khan'),
  _s('FA23-BSE-007', 'Mehak Fatima'),
  _s('FA22-BSE-007', 'Older Batch Seven'),
  _s('FA23-BSE-010', 'Omar Farooq'),
];

void main() {
  test('last three digits find the student', () {
    final r = searchStudentsByRegNo(_students, '010');
    expect(r.map((s) => s.name), ['Omar Farooq']);
  });

  test('same ending in two intakes returns both, sorted by registration number', () {
    final r = searchStudentsByRegNo(_students, '007');
    expect(r.map((s) => s.registrationNumber), ['FA22-BSE-007', 'FA23-BSE-007']);
  });

  test('longer input narrows to one; full number works in any case and format', () {
    expect(searchStudentsByRegNo(_students, 'BSE-007').length, 2);
    expect(searchStudentsByRegNo(_students, 'fa23-bse-007').single.name, 'Mehak Fatima');
    expect(searchStudentsByRegNo(_students, 'FA23 BSE 007').single.name, 'Mehak Fatima');
    expect(searchStudentsByRegNo(_students, 'fa23bse007').single.name, 'Mehak Fatima');
  });

  test('fewer than three characters or no match returns nothing', () {
    expect(searchStudentsByRegNo(_students, ''), isEmpty);
    expect(searchStudentsByRegNo(_students, '07'), isEmpty);
    expect(searchStudentsByRegNo(_students, '99'), isEmpty);
    expect(searchStudentsByRegNo(_students, '999'), isEmpty);
  });

  test('matches the END of the number, not the middle', () {
    // "BSE" appears in every number but none of them ends with it.
    expect(searchStudentsByRegNo(_students, 'BSE'), isEmpty);
    // "23-" digits in the middle must not match either.
    expect(searchStudentsByRegNo(_students, 'FA23'), isEmpty);
  });

  test('normalizeRegNo strips separators and upper-cases', () {
    expect(normalizeRegNo(' fa23-bse 007 '), 'FA23BSE007');
  });
}
