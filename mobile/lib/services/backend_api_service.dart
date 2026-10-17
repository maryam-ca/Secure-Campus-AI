import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class BackendApiException implements Exception {
  final String message;
  const BackendApiException(this.message);
  @override
  String toString() => message;
}

/// Talks to the backend service's /admin/* endpoints (account creation).
/// Every call attaches the current Firebase ID token as a Bearer token;
/// the backend independently re-verifies it and checks the caller is an
/// active Admin (see iris_ai/app/admin_api.py) - this client does not
/// (and should not) trust itself to gate access.
class BackendApiService {
  final String baseUrl;

  BackendApiService({this.baseUrl = AppConfig.backendBaseUrl});

  Future<String> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const BackendApiException('Not signed in.');
    final token = await user.getIdToken();
    if (token == null) throw const BackendApiException('Could not obtain an ID token.');
    return token;
  }

  Future<Map<String, dynamic>> createAccount({
    required String email,
    required String name,
    required String role, // student | security | librarian | driver
    Map<String, dynamic>? studentFields,
    String? password,
  }) async {
    final token = await _idToken();
    final resp = await http
        .post(
          Uri.parse('$baseUrl/admin/accounts'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'email': email,
            'name': name,
            'role': role,
            if (studentFields != null) 'studentFields': studentFields,
            if (password != null && password.isNotEmpty) 'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw BackendApiException(_extractDetail(resp) ?? 'Account creation failed (${resp.statusCode}).');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deactivateAccount(String uid) async {
    final token = await _idToken();
    final resp = await http
        .post(
          Uri.parse('$baseUrl/admin/accounts/deactivate'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'uid': uid}),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw BackendApiException(_extractDetail(resp) ?? 'Deactivation failed (${resp.statusCode}).');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Lets Admin fix a name typo or reset a password on an EXISTING
  /// account - previously the only actions were create/deactivate, with
  /// no way to fix a mistake or help someone who forgot their password.
  /// Pass only what changed; at least one of name/password is required.
  Future<void> updateAccount({
    required String uid,
    required String role,
    String? name,
    String? password,
  }) async {
    final token = await _idToken();
    final resp = await http
        .post(
          Uri.parse('$baseUrl/admin/accounts/update'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'uid': uid,
            'role': role,
            if (name != null && name.isNotEmpty) 'name': name,
            if (password != null && password.isNotEmpty) 'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw BackendApiException(_extractDetail(resp) ?? 'Update failed (${resp.statusCode}).');
    }
  }

  String? _extractDetail(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {
      // response wasn't JSON - fall through to null
    }
    return null;
  }
}