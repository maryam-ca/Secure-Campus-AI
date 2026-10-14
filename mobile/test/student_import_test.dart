import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/student_csv.dart';
import 'package:securecampus/core/utils/student_import.dart';

StudentCsvRow _row(int line, String name) => StudentCsvRow(
      line: line,
      name: name,
      email: '${name.toLowerCase()}@x.edu',
      registrationNumber: 'FA24-BSE-0$line',
      program: 'BSE',
      semester: 1,
      courses: const [],
      errors: const [],
    );

class _Refused implements Exception {
  final String message;
  _Refused(this.message);
}

class _Offline implements Exception {}

Future<List<ImportOutcome>> _run(List<StudentCsvRow> rows, Future<Map<String, dynamic>> Function(StudentCsvRow) create,
        {void Function(int, int)? onProgress}) =>
    importStudents(rows,
        create: create,
        isFatal: (e) => e is _Offline,
        describe: (e) => e is _Refused ? e.message : 'Could not reach the server.',
        onProgress: onProgress);

void main() {
  test('every row is created and the temporary passwords are kept', () async {
    final rows = [_row(2, 'Ayesha'), _row(3, 'Bilal')];
    final outcomes = await _run(rows, (r) async => {'temporaryPassword': 'pw-${r.name}'});

    expect(outcomes.every((o) => o.created), isTrue);
    expect(outcomes.map((o) => o.temporaryPassword), ['pw-Ayesha', 'pw-Bilal']);
  });

  test('a refused row is recorded and the import carries on', () async {
    final rows = [_row(2, 'Ayesha'), _row(3, 'Bilal'), _row(4, 'Omar')];
    final outcomes = await _run(rows, (r) async {
      if (r.name == 'Bilal') throw _Refused('registration number is already in use');
      return {'temporaryPassword': 'pw'};
    });

    expect(outcomes.map((o) => o.created), [true, false, true]);
    expect(outcomes[1].error, 'registration number is already in use');
    expect(outcomes[1].attempted, isTrue);
  });

  test('an unreachable server stops the import; the rest are marked not attempted', () async {
    var calls = 0;
    final rows = [_row(2, 'Ayesha'), _row(3, 'Bilal'), _row(4, 'Omar'), _row(5, 'Sara')];
    final outcomes = await _run(rows, (r) async {
      calls++;
      if (r.name == 'Bilal') throw _Offline();
      return {'temporaryPassword': 'pw'};
    });

    expect(calls, 2, reason: 'no more attempts once the server is unreachable');
    expect(outcomes.map((o) => o.created), [true, false, false, false]);
    expect(outcomes[1].attempted, isTrue);
    expect(outcomes[2].attempted, isFalse);
    expect(outcomes[3].error, contains('Not attempted'));
  });

  test('progress is reported after each row', () async {
    final seen = <String>[];
    await _run([_row(2, 'A'), _row(3, 'B')], (r) async => {'temporaryPassword': 'x'},
        onProgress: (d, t) => seen.add('$d/$t'));
    expect(seen, ['1/2', '2/2']);
  });

  test('the accounts file lists only created rows, with quoting', () async {
    final rows = [_row(2, 'Ayesha'), _row(3, 'Bilal')];
    final outcomes = await _run(rows, (r) async {
      if (r.name == 'Bilal') throw _Refused('no');
      return {'temporaryPassword': 'a,b"c'};
    });
    final csv = createdAccountsCsv(outcomes);
    expect(csv.split('\n').first, 'name,email,registration_number,temporary_password');
    expect(csv, contains('Ayesha,ayesha@x.edu,FA24-BSE-02,"a,b""c"'));
    expect(csv, isNot(contains('Bilal')));
  });
}
