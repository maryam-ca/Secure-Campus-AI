import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/registration_rules.dart';
import 'package:securecampus/core/utils/student_csv.dart';

void main() {
  group('registrationProgramProblem', () {
    test('reads the program out of the number', () {
      expect(programInRegistrationNumber('FA23-BSE-011'), 'BSE');
      expect(programInRegistrationNumber('fa23bsi011'), 'BSI');
      expect(programInRegistrationNumber('LIB/2024/7'), isNull);
    });

    test('same program is fine, whatever the case or spacing', () {
      expect(registrationProgramProblem('FA23-BSE-011', 'BSE'), isNull);
      expect(registrationProgramProblem('fa23-bse-011', ' bse '), isNull);
    });

    test('a different program gives a sentence naming both', () {
      final msg = registrationProgramProblem('FA23-BSI-011', 'BSE')!;
      expect(msg, contains('BSI'));
      expect(msg, contains('BSE'));
    });

    test('other number formats and an empty program are not checked', () {
      expect(registrationProgramProblem('LIB/2024/7', 'BSE'), isNull);
      expect(registrationProgramProblem('FA23-BSE-011', ''), isNull);
    });
  });

  test('a CSV row whose number names another program is flagged', () {
    const csv = 'name,email,registration_number,program,semester,courses\n'
        'Ayesha,a@x.pk,FA23-BSI-011,BSE,3,\n'
        'Bilal,b@x.pk,FA23-BSE-012,BSE,3,\n';
    final result = parseStudentCsv(csv, knownCourseIds: {});
    expect(result.rows[0].errors.join(' '), contains('BSI'));
    expect(result.rows[1].isValid, isTrue);
  });
}
