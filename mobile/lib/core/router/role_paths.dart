import '../constants/roles.dart';

/// The home path of each role's portal.
String homePathForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.student:
      return '/student';
    case UserRole.security:
      return '/security';
    case UserRole.librarian:
      return '/librarian';
    case UserRole.driver:
      return '/driver';
  }
}
