/// A plain sentence for a failed save, so a dialog never just sits there.
String saveFailureMessage(Object error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Not saved: the database refused it. The latest Firestore rules may not be '
        'published to Firebase yet, or this account is not an Admin.';
  }
  return 'Not saved. Check the internet connection and try again.';
}
