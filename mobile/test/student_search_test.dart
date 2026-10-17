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
    );

final _students = [
  _s('FA23-BSE-001', 'Ayesha Khan'),
  _s('FA23-BSE-007', 'Mehak Fatima'),
  _s('FA22-BSE-007', 'Ayesha Malik'),
  _s('FA23-BSE-010', 'Omar Farooq'),
  _s('FA23-BSE-032', 'Ayesha'),
];

List<String> _ids(String q) => searchStudents(_students, q).map((s) => s.registrationNumber).toList();

void main() {
  test('"00" lists every student whose ID contains 00', () {
    // 001, 007 (x2) contain "00"; 010 and 032 do not.
    expect(_ids('00'), ['FA22-BSE-007', 'FA23-BSE-001', 'FA23-BSE-007']);
  });

  test('part of an ID matches anywhere in it, in any case or format', () {
    expect(_ids('007'), ['FA22-BSE-007', 'FA23-BSE-007']);
    expect(_ids('bse-01'), ['FA23-BSE-010']);
    expect(_ids('fa23 bse 007'), ['FA23-BSE-007']);
    expect(_ids('FA23BSE032'), ['FA23-BSE-032']);
  });

  test('"ayesh" lists every student with those letters in the name', () {
    expect(_ids('ayesh'), ['FA22-BSE-007', 'FA23-BSE-001', 'FA23-BSE-032']);
    expect(_ids('AYESH'), ['FA22-BSE-007', 'FA23-BSE-001', 'FA23-BSE-032']);
  });

  test('name search works for any part, including a second word', () {
    expect(_ids('khan'), ['FA23-BSE-001']);
    expect(_ids('ha K'), ['FA23-BSE-001']); // "Ayesha Khan" contains "ha k"
  });

  test('a single match is still returned as a list (nothing auto-picked)', () {
    final r = searchStudents(_students, 'omar');
    expect(r.length, 1);
    expect(r.single.name, 'Omar Farooq');
  });

  test('fewer than 2 characters or no match returns nothing', () {
    expect(_ids(''), isEmpty);
    expect(_ids('a'), isEmpty);
    expect(_ids(' 0 '), isEmpty);
    expect(_ids('zzz'), isEmpty);
    expect(_ids('999'), isEmpty);
  });

  test('normalizeRegNo strips separators and upper-cases', () {
    expect(normalizeRegNo(' fa23-bse 007 '), 'FA23BSE007');
  });
}
