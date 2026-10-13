// Real Firebase config for project campus-a4087 - Android values from
// the uploaded google-services.json, Web values from the Firebase
// Console "Add app" flow. iOS not configured yet (not needed for
// Android/Chrome testing).

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS Firebase config has not been provided yet - only the Android '
          'google-services.json was uploaded. Download GoogleService-Info.plist '
          'for this project from Firebase Console (Project settings -> Your '
          'apps -> add/select the iOS app) and either run `flutterfire '
          'configure` or send it over so the `ios` FirebaseOptions below can '
          'be filled in with real values the same way `android`/`web` were.',
        );
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // Real values, copied verbatim from the uploaded google-services.json
  // for project campus-a4087.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDz1Wa53_Bk3ejy80pIdUCG46oB5ypMx_8',
    appId: '1:814575777249:android:760fb3ec5824888b640ea0',
    messagingSenderId: '814575777249',
    projectId: 'campus-a4087',
    storageBucket: 'campus-a4087.firebasestorage.app',
    databaseURL: 'https://campus-a4087-default-rtdb.firebaseio.com',
  );

  // Real values, from the Firebase Console Web app registration for
  // campus-a4087.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZ19QdhDOXS0ZXZJpNgfRlGfQXjxLzYNk',
    appId: '1:814575777249:web:ba46d5b223c76a95640ea0',
    messagingSenderId: '814575777249',
    projectId: 'campus-a4087',
    authDomain: 'campus-a4087.firebaseapp.com',
    storageBucket: 'campus-a4087.firebasestorage.app',
    databaseURL: 'https://campus-a4087-default-rtdb.firebaseio.com',
  );

  // Fill in once you've downloaded GoogleService-Info.plist for an iOS
  // app registered under campus-a4087.
  //
  // static const FirebaseOptions ios = FirebaseOptions(
  //   apiKey: '...',
  //   appId: '...',
  //   messagingSenderId: '814575777249',
  //   projectId: 'campus-a4087',
  //   storageBucket: 'campus-a4087.firebasestorage.app',
  //   iosBundleId: 'com.example.securecampus',
  // );
}