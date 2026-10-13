import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth. No mock/offline mode exists here on
/// purpose (spec §46) — every call is a real request to Firebase Auth.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Sign-in did not return a user. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Used only by the public "report a found card" flow (spec §23) so
  /// a non-account-holding finder can submit one Firestore write
  /// without needing a real SecureCampus account. See
  /// features/common/found_card_report_screen.dart.
  Future<User> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw const AuthFailure('Could not start an anonymous session. Please try again.');
    }
    return user;
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been deactivated. Contact Admin.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Sign-in failed (${e.code}). Please try again or contact Admin.';
    }
  }
}

/// A user-facing auth error with an already-friendly message, distinct
/// from the raw FirebaseAuthException so the UI layer never has to know
/// about Firebase-specific error codes.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}
