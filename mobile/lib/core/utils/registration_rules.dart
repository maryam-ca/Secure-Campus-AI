/// A registration number carries the program: FA23-BSE-011 is a BSE student, so
/// Program BSE must not be paired with FA23-BSI-011. The account service checks
/// the same rule (iris_ai/app/registration.py); checking it here as well lets the
/// Admin fix it before anything is sent.
library;

// session + year, program letters, serial: FA23-BSE-011, FA23BSE011, fa23 bse 011
final _registrationPattern = RegExp(r'^[A-Za-z]{2,4}\d{2}[-\s]?([A-Za-z]+)[-\s]?\d+$');

String _clean(String value) => value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// The program letters inside the number ("BSE"), or null if the number is in
/// some other format (those are accepted unchecked).
String? programInRegistrationNumber(String registrationNumber) =>
    _registrationPattern.firstMatch(registrationNumber.trim())?.group(1)?.toUpperCase();

/// A sentence if the number names a different program than [program], else null.
String? registrationProgramProblem(String registrationNumber, String program) {
  final inNumber = programInRegistrationNumber(registrationNumber);
  if (inNumber == null || program.trim().isEmpty) return null;
  if (inNumber == _clean(program)) return null;
  return 'Registration number ${registrationNumber.trim()} is for program $inNumber, but the program is '
      '${program.trim().toUpperCase()}. They must be the same.';
}
