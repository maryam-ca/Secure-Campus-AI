/// Compile-time configuration via `--dart-define`, so nothing
/// environment-specific (like the backend service's local-network
/// address) is hardcoded in source. Example:
///
///   flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.50:8000
///
/// Defaults to localhost, which is correct when running an emulator on
/// the same machine as the iris_ai/admin backend service; a physical
/// phone needs the machine's real LAN IP instead.
class AppConfig {
  AppConfig._();

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
