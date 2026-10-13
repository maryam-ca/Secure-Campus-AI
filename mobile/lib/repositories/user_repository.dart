import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Reads the users/{uid} document that carries role + active status.
/// This is the single source of truth the router uses to decide which
/// portal a signed-in account can reach (spec §5 - role enforcement in
/// Flutter navigation, backed independently by Firestore rules).
class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  Future<AppUser> fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw StateError(
        'No users/$uid document found. Accounts must be created by Admin '
        '(or scripts/seed_firebase.py for the initial dataset) before they can sign in.',
      );
    }
    return AppUser.fromFirestore(doc);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }
}
