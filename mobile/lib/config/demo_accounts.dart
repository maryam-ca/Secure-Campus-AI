import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One-tap test logins for the login screen.
///
/// The list is NOT stored in source code. It arrives as a build-time
/// `--dart-define` (see scripts/make_demo_defines.py) and is only ever
/// exposed in debug builds, so a normal build or any release build shows
/// no accounts at all.
class DemoAccount {
  final String role;
  final String label;
  final String email;
  final String password;

  const DemoAccount({required this.role, required this.label, required this.email, required this.password});

  factory DemoAccount.fromJson(Map<String, dynamic> json) => DemoAccount(
        role: json['role'] as String? ?? '',
        label: json['label'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
      );
}

class DemoAccounts {
  DemoAccounts._();

  static const String _raw = String.fromEnvironment('DEMO_ACCOUNTS');

  /// Empty unless this is a debug build that was given DEMO_ACCOUNTS.
  static final List<DemoAccount> all = kDebugMode ? parse(_raw) : const [];

  /// Tolerant parser: bad or missing input yields an empty list, never a crash.
  @visibleForTesting
  static List<DemoAccount> parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DemoAccount.fromJson)
          .where((a) => a.email.isNotEmpty && a.password.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
