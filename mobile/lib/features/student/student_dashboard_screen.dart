import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/roles.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/student_providers.dart';
import 'widgets/attendance_section.dart';
import 'widgets/bus_assignment_section.dart';
import 'widgets/library_section.dart';
import 'widgets/notifications_section.dart';
import 'widgets/student_home_section.dart';

/// Shows only the signed-in student's own data - profile, their own
/// registered courses' attendance, their own bus assignment, their own
/// library records, their own notifications - each as its own tab
/// (separate screens, not one long scrolling list), reached via bottom
/// navigation the same way the Librarian portal is structured.
/// Deliberately excludes everything spec §8 lists as off-limits: other
/// students' data, gate history, the live bus map, and security alerts.
class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  int _tab = StudentTab.home;

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentProfileProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);

    return PortalScaffold(
      title: 'My Campus',
      role: UserRole.student,
      body: studentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load your profile.\n$err', textAlign: TextAlign.center)),
        data: (student) {
          if (student == null) {
            return const Center(child: Text('No student record found for this account.'));
          }
          final tabs = <Widget>[
            StudentHomeSection(onOpenTab: (i) => setState(() => _tab = i)),
            const AttendanceSection(),
            const BusAssignmentSection(),
            const LibrarySection(),
            const NotificationsSection(),
          ];
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(key: ValueKey(_tab), child: tabs[_tab]),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Attendance'),
          const NavigationDestination(icon: Icon(Icons.directions_bus_filled_outlined), label: 'Bus'),
          const NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Library'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
