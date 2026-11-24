/// Compile-time configuration via `--dart-define`, so nothing
/// environment-specific (like the backend service's local-network
/// address) is hardcoded in source. Example:
///
///   flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.50:8000
///
/// Defaults to 127.0.0.1 (the same machine as the backend service). It is
/// written as an address, not "localhost": on Windows "localhost" tries the
/// IPv6 address first, finds nothing there and only then falls back, which made
/// every account call about 30 times slower (0.22 s against 0.007 s here).
/// A physical phone needs the machine's real LAN IP instead.
class AppConfig {
  AppConfig._();

  static const String _fromDefine = String.fromEnvironment('BACKEND_BASE_URL');

  /// Built-in address (this PC), or the one given with --dart-define.
  static const String backendBaseUrl = _fromDefine == '' ? 'http://127.0.0.1:8000' : _fromDefine;

  /// True when an address was given at build time; it then overrides the one
  /// the service publishes (see core/utils/backend_address.dart).
  static const bool backendUrlIsCustom = _fromDefine != '';
}
