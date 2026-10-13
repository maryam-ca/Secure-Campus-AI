import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/roles.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final bool active;
  final bool mustResetPassword;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    this.mustResetPassword = false,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('users/${doc.id} has no data - account was not provisioned correctly');
    }
    final role = UserRoleX.fromId(data['role'] as String?);
    if (role == null) {
      throw StateError('users/${doc.id} has an invalid or missing role');
    }
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: role,
      active: data['active'] as bool? ?? false,
      mustResetPassword: data['mustResetPassword'] as bool? ?? false,
    );
  }
}
