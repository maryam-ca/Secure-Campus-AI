/// Reading and checking a CSV of students before anything is created.
///
/// Columns (header row required, any order, names are case-insensitive):
///   name, email, registration_number, program, semester, courses
/// `courses` holds course IDs separated by `;` or `|` (e.g. `SE;AI;DBS`).
/// `program` defaults to BSE and `semester` to 1 when left empty.
///
/// Nothing here talks to Firebase: it only parses and validates, so the Admin
/// can see exactly what is wrong in which row *before* importing.
library;

class StudentCsvRow {
  /// 1-based line number in the file (the header is line 1).
  final int line;
  final String name;
  final String email;
  final String registrationNumber;
  final String program;
  final int semester;
  final List<String> courses;
  final List<String> errors;

  const StudentCsvRow({
    required this.line,
    required this.name,
    required this.email,
    required this.registrationNumber,
    required this.program,
    required this.semester,
    required this.courses,
    required this.errors,
  });

  bool get isValid => errors.isEmpty;
}

class StudentCsvResult {
  /// Problems with the file as a whole (missing column, empty file ...).
  final List<String> fileErrors;
  final List<StudentCsvRow> rows;
  const StudentCsvResult({required this.fileErrors, required this.rows});

  List<StudentCsvRow> get valid => rows.where((r) => r.isValid).toList();
  List<StudentCsvRow> get invalid => rows.where((r) => !r.isValid).toList();
}

/// A header row plus one example, for the "copy template" button.
const studentCsvTemplate = 'name,email,registration_number,program,semester,courses\n'
    'Ayesha Khan,fa24-bse-011@securecampus.edu.pk,FA24-BSE-011,BSE,3,SE;AI\n';

const _aliases = <String, String>{
  'name': 'name',
  'fullname': 'name',
  'studentname': 'name',
  'email': 'email',
  'emailaddress': 'email',
  'registrationnumber': 'reg',
  'registrationno': 'reg',
  'regnumber': 'reg',
  'regno': 'reg',
  'reg': 'reg',
  'program': 'program',
  'programme': 'program',
  'semester': 'semester',
  'sem': 'semester',
  'courses': 'courses',
  'course': 'courses',
};

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _regPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{2,29}$');

/// Parses CSV text into rows (handles quotes, commas and line breaks inside
/// quotes, CRLF, and a leading byte-order mark).
List<List<String>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    // skip completely empty lines
    if (row.length > 1 || row.first.trim().isNotEmpty) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c == '\r') {
      // part of CRLF, or a lone CR used as a line break
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Parses and checks a students CSV.
///
/// [knownCourseIds]: IDs that exist (rows naming others are flagged).
/// [existingRegistrationNumbers] / [existingEmails]: already in the system
/// (rows repeating them are flagged), compared ignoring case.
StudentCsvResult parseStudentCsv(
  String text, {
  required Set<String> knownCourseIds,
  Set<String> existingRegistrationNumbers = const {},
  Set<String> existingEmails = const {},
}) {
  final table = parseCsv(text);
  if (table.isEmpty) {
    return const StudentCsvResult(fileErrors: ['The file is empty.'], rows: []);
  }

  String norm(String h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  final columns = <String, int>{};
  for (var i = 0; i < table.first.length; i++) {
    final key = _aliases[norm(table.first[i])];
    if (key != null) columns.putIfAbsent(key, () => i);
  }

  final fileErrors = <String>[
    for (final needed in const {'name': 'name', 'email': 'email', 'reg': 'registration_number'}.entries)
      if (!columns.containsKey(needed.key)) 'Missing a "${needed.value}" column in the header row.',
  ];
  if (fileErrors.isNotEmpty) return StudentCsvResult(fileErrors: fileErrors, rows: const []);
  if (table.length == 1) {
    return const StudentCsvResult(fileErrors: ['There are no student rows under the header.'], rows: []);
  }

  String cellAt(List<String> r, String key) {
    final i = columns[key];
    return (i == null || i >= r.length) ? '' : r[i].trim();
  }

  final known = knownCourseIds.map((c) => c.toLowerCase()).toSet();
  final existingRegs = existingRegistrationNumbers.map((r) => r.toLowerCase()).toSet();
  final existingMails = existingEmails.map((e) => e.toLowerCase()).toSet();
  final seenRegs = <String>{};
  final seenMails = <String>{};

  final rows = <StudentCsvRow>[];
  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    final errors = <String>[];

    final name = cellAt(r, 'name');
    final email = cellAt(r, 'email');
    final reg = cellAt(r, 'reg');
    final program = cellAt(r, 'program').isEmpty ? 'BSE' : cellAt(r, 'program');
    final semText = cellAt(r, 'semester');
    final courseText = cellAt(r, 'courses');

    if (name.isEmpty) errors.add('Name is empty.');

    if (email.isEmpty) {
      errors.add('Email is empty.');
    } else if (!_emailPattern.hasMatch(email)) {
      errors.add('"$email" is not a valid email.');
    } else if (existingMails.contains(email.toLowerCase())) {
      errors.add('Email $email already has an account.');
    } else if (!seenMails.add(email.toLowerCase())) {
      errors.add('Email $email appears twice in this file.');
    }

    if (reg.isEmpty) {
      errors.add('Registration number is empty.');
    } else if (!_regPattern.hasMatch(reg)) {
      errors.add('"$reg" is not a valid registration number (letters, digits and dashes, at least 3 characters).');
    } else if (existingRegs.contains(reg.toLowerCase())) {
      errors.add('Registration number $reg already exists.');
    } else if (!seenRegs.add(reg.toLowerCase())) {
      errors.add('Registration number $reg appears twice in this file.');
    }

    var semester = 1;
    if (semText.isNotEmpty) {
      final parsed = int.tryParse(semText);
      if (parsed == null || parsed < 1 || parsed > 12) {
        errors.add('Semester "$semText" must be a number from 1 to 12.');
      } else {
        semester = parsed;
      }
    }

    final courses = courseText.isEmpty
        ? <String>[]
        : courseText.split(RegExp(r'[;|]')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    for (final c in courses) {
      if (!known.contains(c.toLowerCase())) errors.add('Unknown course "$c".');
    }

    rows.add(StudentCsvRow(
      line: i + 1,
      name: name,
      email: email,
      registrationNumber: reg,
      program: program,
      semester: semester,
      // use the course IDs exactly as they exist in the system
      courses: [
        for (final c in courses) knownCourseIds.firstWhere((k) => k.toLowerCase() == c.toLowerCase(), orElse: () => c),
      ],
      errors: errors,
    ));
  }

  return StudentCsvResult(fileErrors: const [], rows: rows);
}
