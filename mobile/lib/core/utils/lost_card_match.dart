/// How a finder's report compares with the real student record.
enum CardMatch {
  /// The registration number exists and the name given belongs to it.
  verified,

  /// The registration number exists but the name given is not that student's.
  nameMismatch,

  /// No student has this registration number.
  unknownStudent,
}

/// Registration numbers are stored upper case; finders may type any case.
String normalizeRegistration(String raw) => raw.trim().toUpperCase();

String _squash(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ').trim();

/// Compares what the finder typed with the registered student, if there is one.
///
/// The name matches when every word the finder gave appears in the registered
/// name (so "Ayesha Khan" matches "Ayesha Bibi Khan", in any case), and at
/// least one word was given.
CardMatch matchCard({required String? registeredName, required String enteredName}) {
  if (registeredName == null) return CardMatch.unknownStudent;

  final entered = _squash(enteredName).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final registered = _squash(registeredName).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
  if (entered.isEmpty) return CardMatch.nameMismatch;

  return entered.every(registered.contains) ? CardMatch.verified : CardMatch.nameMismatch;
}
