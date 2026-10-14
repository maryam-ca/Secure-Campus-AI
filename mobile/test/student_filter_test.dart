import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/student_filter.dart';
import 'package:securecampus/models/student_model.dart';

StudentModel _s(String reg, String name, {int sem = 5, bool iris = false, String program = 'BSE', String? email}) =>
    StudentModel(
      uid: 'u-$reg',
      registrationNumber: reg,
      name: name,
      program: program,
      semester: sem,
      email: email ?? '${reg.toLowerCase()}@securecampus.edu.pk',
      courseIds: const [],
      irisEnrolled: iris,
    );

final _all = [
  _s('FA23-BSE-007', 'Mehak Fatima', sem: 5, iris: true),
  _s('FA23-BSE-001', 'Ayesha Khan', sem: 5),
  _s('FA22-BCS-010', 'Omar Farooq', sem: 7, iris: true, program: 'BCS'),
  _s('FA24-BSE-003', 'Bilal Ahmed', sem: 3),
];

List<String> _ids(List<StudentModel> l) => l.map((s) => s.registrationNumber).toList();

void main() {
  test('no filters: everyone, sorted by registration number', () {
    expect(_ids(filterStudents(_all)), ['FA22-BCS-010', 'FA23-BSE-001', 'FA23-BSE-007', 'FA24-BSE-003']);
  });

  test('text matches name, program, email and any part of the ID', () {
    expect(_ids(filterStudents(_all, query: 'ayesh')), ['FA23-BSE-001']);
    expect(_ids(filterStudents(_all, query: 'bcs')), ['FA22-BCS-010']);
    expect(_ids(filterStudents(_all, query: 'bilal')), ['FA24-BSE-003']);
    expect(_ids(filterStudents(_all, query: '007')), ['FA23-BSE-007']);
    expect(_ids(filterStudents(_all, query: 'fa23 bse')), ['FA23-BSE-001', 'FA23-BSE-007']);
    expect(_ids(filterStudents(_all, query: 'FA23BSE001')), ['FA23-BSE-001']);
    expect(filterStudents(_all, query: 'zzz'), isEmpty);
  });

  test('iris filter', () {
    expect(_ids(filterStudents(_all, iris: IrisFilter.enrolled)), ['FA22-BCS-010', 'FA23-BSE-007']);
    expect(_ids(filterStudents(_all, iris: IrisFilter.notEnrolled)), ['FA23-BSE-001', 'FA24-BSE-003']);
  });

  test('semester filter, combined with the others', () {
    expect(_ids(filterStudents(_all, semester: 5)), ['FA23-BSE-001', 'FA23-BSE-007']);
    expect(_ids(filterStudents(_all, semester: 5, iris: IrisFilter.enrolled)), ['FA23-BSE-007']);
    expect(_ids(filterStudents(_all, semester: 5, query: 'mehak', iris: IrisFilter.enrolled)), ['FA23-BSE-007']);
    expect(filterStudents(_all, semester: 8), isEmpty);
  });

  test('counts and the list of semesters', () {
    final c = irisCounts(_all);
    expect([c.all, c.enrolled, c.notEnrolled], [4, 2, 2]);
    expect(semestersIn(_all), [3, 5, 7]);
  });
}
