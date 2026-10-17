import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which page of the Admin portal is open. The value is an [AdminSection] id;
/// the sidebar and the dashboard cards both set it. The pages themselves are
/// listed in admin_nav.dart.
final adminSectionProvider = StateProvider<String>((ref) => AdminSection.dashboard);

/// Page ids. A main module's own landing page uses its group id (see
/// AdminNavGroup.id). Sub-modules have their own id (e.g. Library > Catalog and
/// Library > Reports) so the sidebar and dashboard can open them directly.
class AdminSection {
  AdminSection._();
  static const dashboard = 'dashboard';

  // Phase 1
  static const students = 'students';
  static const staffSecurity = 'staff.security';
  static const staffLibrarian = 'staff.librarian';
  static const staffDriver = 'staff.driver';
  static const courses = 'courses';
  static const libraryCatalog = 'library.catalog';
  static const libraryReports = 'library.reports';
  static const bus = 'bus';
  static const stops = 'stops';
  static const lostCards = 'lost-cards';

  // Phase 2 (under development, not clickable yet)
  static const camera = 'camera';
  static const attendance = 'attendance';
  static const gateSecurity = 'gate-security';
  static const settings = 'settings';
}
