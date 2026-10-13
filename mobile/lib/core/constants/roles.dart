/// The exactly-five application roles (spec §5). There is deliberately
/// no Teacher role and no "unknown"/generic role — an account either
/// has one of these five, or authentication is treated as invalid.
enum UserRole { admin, student, security, librarian, driver }

extension UserRoleX on UserRole {
  String get id => name; // matches the string stored in Firestore users/{uid}.role

  static UserRole? fromId(String? id) {
    for (final role in UserRole.values) {
      if (role.id == id) return role;
    }
    return null;
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.student:
        return 'Student';
      case UserRole.security:
        return 'Security Staff';
      case UserRole.librarian:
        return 'Librarian';
      case UserRole.driver:
        return 'Driver';
    }
  }
}
