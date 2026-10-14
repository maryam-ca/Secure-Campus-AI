import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/student_csv.dart';

const _courses = {'SE', 'AI', 'DBS'};

StudentCsvResult _parse(String csv, {Set<String> regs = const {}, Set<String> emails = const {}}) =>
    parseStudentCsv(csv, knownCourseIds: _courses, existingRegistrationNumbers: regs, existingEmails: emails);

void main() {
  group('parseCsv', () {
    test('plain rows, CRLF, blank lines and a byte-order mark', () {
      expect(parseCsv('﻿a,b\r\n1,2\r\n\r\n3,4\r\n'), [
        ['a', 'b'],
        ['1', '2'],
        ['3', '4'],
      ]);
    });

    test('quoted cells with commas, quotes and line breaks', () {
      expect(parseCsv('n,note\n"Khan, Ayesha","said ""hi""\nthere"\n'), [
        ['n', 'note'],
        ['Khan, Ayesha', 'said "hi"\nthere'],
      ]);
    });

    test('a last line without a trailing newline is kept', () {
      expect(parseCsv('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
  });

  group('parseStudentCsv', () {
    const header = 'name,email,registration_number,program,semester,courses\n';

    test('a good row is valid and fully read', () {
      final r = _parse('${header}Ayesha Khan,a@x.edu,FA24-BSE-011,BCS,3,SE;AI\n');
      expect(r.fileErrors, isEmpty);
      final row = r.rows.single;
      expect(row.isValid, isTrue);
      expect([row.name, row.email, row.registrationNumber, row.program, row.semester, row.courses],
          ['Ayesha Khan', 'a@x.edu', 'FA24-BSE-011', 'BCS', 3, ['SE', 'AI']]);
      expect(row.line, 2);
    });

    test('empty program and semester fall back to BSE and 1; courses may be empty or use |', () {
      final r = _parse('${header}A,a@x.edu,FA24-BSE-011,,,\nB,b@x.edu,FA24-BSE-012,BSE,2,se|dbs\n');
      expect(r.rows[0].program, 'BSE');
      expect(r.rows[0].semester, 1);
      expect(r.rows[0].courses, isEmpty);
      expect(r.rows[1].courses, ['SE', 'DBS']); // matched ignoring case, stored as the real IDs
    });

    test('headers are case-insensitive, any order, with common aliases', () {
      final r = _parse('Reg No,Full Name,Email Address,Semester\nFA24-BSE-011,Ayesha,a@x.edu,4\n');
      expect(r.fileErrors, isEmpty);
      expect(r.rows.single.name, 'Ayesha');
      expect(r.rows.single.registrationNumber, 'FA24-BSE-011');
      expect(r.rows.single.semester, 4);
    });

    test('a missing required column is a file error and nothing is imported', () {
      final r = _parse('name,email\nA,a@x.edu\n');
      expect(r.rows, isEmpty);
      expect(r.fileErrors.single, contains('registration_number'));
    });

    test('empty file, or a header with no students', () {
      expect(_parse('').fileErrors.single, contains('empty'));
      expect(_parse(header).fileErrors.single, contains('no student rows'));
    });

    test('each problem is reported on its own row with a plain message', () {
      final r = _parse('${header}'
          ',not-an-email,FA24-BSE-011,BSE,2,SE\n'
          'B,b@x.edu,,BSE,2,SE\n'
          'C,c@x.edu,FA24-BSE-013,BSE,20,SE\n'
          'D,d@x.edu,FA24-BSE-014,BSE,2,XX\n');
      expect(r.valid, isEmpty);
      expect(r.rows[0].errors, containsAll(['Name is empty.', '"not-an-email" is not a valid email.']));
      expect(r.rows[1].errors, ['Registration number is empty.']);
      expect(r.rows[2].errors.single, contains('from 1 to 12'));
      expect(r.rows[3].errors, ['Unknown course "XX".']);
    });

    test('repeats inside the file and clashes with existing students are flagged', () {
      final r = _parse('${header}'
          'A,a@x.edu,FA24-BSE-011,BSE,1,\n'
          'B,a@x.edu,FA24-BSE-012,BSE,1,\n'
          'C,c@x.edu,fa24-bse-011,BSE,1,\n'
          'D,d@x.edu,FA24-BSE-099,BSE,1,\n'
          'E,e@x.edu,FA24-BSE-098,BSE,1,\n',
          regs: {'FA24-BSE-099'},
          emails: {'E@X.EDU'});
      expect(r.rows[0].isValid, isTrue);
      expect(r.rows[1].errors.single, contains('appears twice'));
      expect(r.rows[2].errors.single, contains('appears twice'));
      expect(r.rows[3].errors.single, contains('already exists'));
      expect(r.rows[4].errors.single, contains('already has an account'));
      expect(r.valid.length, 1);
      expect(r.invalid.length, 4);
    });

    test('the bundled template parses cleanly', () {
      final r = _parse(studentCsvTemplate);
      expect(r.fileErrors, isEmpty);
      expect(r.rows.single.isValid, isTrue);
    });
  });
}
