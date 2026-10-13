import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart' show DefaultFirebaseOptions;

/// Without this, the backend's notify_user()/notify_role() calls
/// find no `users/{uid}.fcmToken` to send to.
///
/// This service:
/// - Requests notification permission
/// - Gets the FCM device token
/// - Saves the token against the signed-in user
/// - Updates the token when Firebase refreshes it
/// - Provides foreground FCM messages
class PushNotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  /// Fires whenever a push notification arrives while the app
  /// is in the foreground.
  ///
  /// main.dart listens to this stream and displays an in-app banner.
  Stream<RemoteMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage;

  /// Requests notification permission and registers the current
  /// device's FCM token for the signed-in user.
  Future<void> registerTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(user.uid, token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUid != null) {
        _saveToken(currentUid, newToken);
      }
    });
  }

  /// Saves the FCM token for the current user.
  Future<void> _saveToken(String uid, String token) {
    return _db.collection('users').doc(uid).set(
      {
        'fcmToken': token,
      },
      SetOptions(merge: true),
    );
  }
}

/// Handles FCM messages when the app is running in the background
/// or is terminated.
///
/// IMPORTANT:
/// This function runs in a separate isolate on Android.
///
/// Firebase must be initialized in that isolate, but we first check
/// whether a Firebase app already exists to prevent:
///
/// [core/duplicate-app] A Firebase App named "[DEFAULT]" already exists
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Firebase may already be initialized.
    // The notification itself is handled by the OS for
    // notification-type FCM messages.
  }
}