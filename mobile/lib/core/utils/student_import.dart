import 'student_csv.dart';

/// What happened to one CSV row when it was imported.
class ImportOutcome {
  final StudentCsvRow row;
  final bool created;

  /// The temporary password, shown once so the Admin can hand it over.
  final String? temporaryPassword;

  /// Why it failed, or why it was not attempted.
  final String? error;
  final bool attempted;

  const ImportOutcome.created(this.row, this.temporaryPassword)
      : created = true,
        error = null,
        attempted = true;

  const ImportOutcome.failed(this.row, this.error)
      : created = false,
        temporaryPassword = null,
        attempted = true;

  const ImportOutcome.skipped(this.row, this.error)
      : created = false,
        temporaryPassword = null,
        attempted = false;
}

/// Creates the accounts one at a time.
///
/// * [create] makes one account and returns the server's reply (it must contain
///   `temporaryPassword`); it throws if the server refuses.
/// * A refused row (a duplicate that appeared meanwhile, a bad value) is
///   recorded and the import carries on with the next row.
/// * If [isFatal] says the error means the server cannot be reached (not a
///   refusal of that row), the import stops and the remaining rows are marked
///   as not attempted, so a dead connection does not produce hundreds of errors.
Future<List<ImportOutcome>> importStudents(
  List<StudentCsvRow> rows, {
  required Future<Map<String, dynamic>> Function(StudentCsvRow row) create,
  required bool Function(Object error) isFatal,
  required String Function(Object error) describe,
  void Function(int done, int total)? onProgress,
}) async {
  final outcomes = <ImportOutcome>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    try {
      final reply = await create(row);
      outcomes.add(ImportOutcome.created(row, reply['temporaryPassword'] as String?));
    } catch (e) {
      if (isFatal(e)) {
        outcomes.add(ImportOutcome.failed(row, describe(e)));
        for (final rest in rows.skip(i + 1)) {
          outcomes.add(ImportOutcome.skipped(rest, 'Not attempted: the server could not be reached.'));
        }
        onProgress?.call(rows.length, rows.length);
        return outcomes;
      }
      outcomes.add(ImportOutcome.failed(row, describe(e)));
    }
    onProgress?.call(i + 1, rows.length);
  }
  return outcomes;
}

/// "email,temporary_password" lines for the accounts that were created, so the
/// Admin can pass the passwords on. Contains secrets: shown/copied only on request.
String createdAccountsCsv(List<ImportOutcome> outcomes) {
  final b = StringBuffer('name,email,registration_number,temporary_password\n');
  for (final o in outcomes.where((o) => o.created)) {
    String q(String v) => v.contains(',') || v.contains('"') ? '"${v.replaceAll('"', '""')}"' : v;
    b.writeln('${q(o.row.name)},${q(o.row.email)},${q(o.row.registrationNumber)},${q(o.temporaryPassword ?? '')}');
  }
  return b.toString();
}
