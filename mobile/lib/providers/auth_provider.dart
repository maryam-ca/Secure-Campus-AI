import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

/// True once the user has changed their password in this session. Stops the
/// forced screen coming back right after a successful change even if clearing
/// the flag in Firestore was refused (e.g. rules not published yet).
final passwordChangedThisSessionProvider = StateProvider<bool>((ref) => false);

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService());

/// Raw Firebase Auth state - fires whenever sign-in/sign-out happens.
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Registers this device's FCM token against the signed-in user as soon
/// as we see one, so backend-sent notifications (unknown-person alerts,
/// lost card, overdue books, bus 10-minute alert) actually arrive as
/// device pushes - not just Firestore records the app has to be open to
/// see. Fire-and-forget: a failure here must never block sign-in, so
/// errors are swallowed rather than surfaced.
final _pushRegistrationProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(firebaseAuthStateProvider, (previous, next) {
    final user = next.value;
    if (user != null) {
      ref.read(pushNotificationServiceProvider).registerTokenForCurrentUser().catchError((_) {});
    }
  });
});

/// The signed-in account's role/profile document, kept live so an Admin
/// deactivating a user (or changing their role) is reflected immediately
/// without requiring the app to be restarted. Emits null when signed out
/// or when the users/{uid} document does not exist / fails to parse -
/// the router treats either as "not authorized", never as a fallback role.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  ref.watch(_pushRegistrationProvider);
  final firebaseUser = ref.watch(firebaseAuthStateProvider).value;
  if (firebaseUser == null) return Stream.value(null);

  return ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid).handleError((_) {
    // Deliberately swallow to null rather than crash the app if the
    // users/{uid} doc is missing/malformed - the router surfaces this
    // as an "account not set up correctly" state instead.
  }).map((user) => user);
});

/// Foreground FCM messages, for main.dart to turn into an on-screen
/// banner (fixed after audit - see push_notification_service.dart).
final foregroundMessageProvider = StreamProvider<RemoteMessage>((ref) {
  return ref.watch(pushNotificationServiceProvider).foregroundMessages;
});
