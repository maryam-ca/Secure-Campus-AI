/// Rules for a new password. Returns a message to show the user, or null if the
/// password is acceptable. Kept in one pure function so it is easy to test and
/// the screen only has to display the result.
///
/// A new password must be at least 8 characters, contain a letter and a digit,
/// differ from the current password, and not simply repeat the person's
/// registration number or the part of their email before the @ (the things an
/// outsider would try first).
String? validateNewPassword({
  required String newPassword,
  required String confirm,
  String? current,
  String? registrationNumber,
  String? email,
}) {
  if (newPassword.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(newPassword) || !RegExp(r'\d').hasMatch(newPassword)) {
    return 'Include at least one letter and one number.';
  }
  if (newPassword.trim() != newPassword) return 'The password cannot start or end with a space.';
  if (current != null && current.isNotEmpty && newPassword == current) {
    return 'The new password must be different from the current one.';
  }

  String squash(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final candidate = squash(newPassword);
  final guessable = <String>[
    if (registrationNumber != null && registrationNumber.trim().isNotEmpty) squash(registrationNumber),
    if (email != null && email.contains('@')) squash(email.split('@').first),
  ].where((g) => g.isNotEmpty);
  for (final g in guessable) {
    if (candidate == g) return 'Choose something that is not your registration number or email.';
  }

  if (newPassword != confirm) return 'The two passwords do not match.';
  return null;
}
