import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which section of the Admin portal is open (index into the section list in
/// admin_home_shell.dart). Shared so dashboard cards can jump to a section.
final adminSectionProvider = StateProvider<int>((ref) => 0);

/// Section indexes, in the same order as the shell's drawer.
class AdminSection {
  AdminSection._();
  static const dashboard = 0;
  static const students = 1;
  static const courses = 2;
  static const camera = 3;
  static const library = 4;
  static const bus = 5;
  static const gateSecurity = 6;
  static const lostCards = 7;
  static const staff = 8;
}
