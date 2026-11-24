/// Which address the app uses to reach the account service.
///
/// - an address given at build time (`--dart-define=BACKEND_BASE_URL=...`) always wins;
/// - on the web the service is on the same PC, so the built-in address is right;
/// - on a phone "localhost" is the phone itself, so the address the service
///   published to Firestore (`config/backend`) is used;
/// - until that is known, or if there is none, the built-in address.
String chooseBackendUrl({
  required String? discovered,
  required bool isWeb,
  required bool customDefine,
  required String fallback,
}) {
  if (customDefine || isWeb) return fallback;
  final url = discovered?.trim() ?? '';
  return url.isEmpty ? fallback : url;
}
