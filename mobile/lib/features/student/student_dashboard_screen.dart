import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/portal_nav.dart';
import '../../core/widgets/portal_shell.dart';
import '../../providers/student_providers.dart';
import 'widgets/bus_assignment_section.dart';
import 'widgets/courses_section.dart';
import 'widgets/library_section.dart';
import 'widgets/notifications_section.dart';
import 'widgets/student_home_section.dart';

/// Which page of the Student portal is open (one of [StudentPage]'s ids).
final studentPageProvider = StateProvider<String>((ref) => StudentPage.home);

/// Page ids, in the same order as [StudentTab] so the Home tiles can jump by
/// tab number.
class StudentPage {
  StudentPage._();
  static const home = 'home';
  static const courses = 'courses';
  static const bus = 'bus';
  static const library = 'library';
  static const alerts = 'alerts';
  static const attendance = 'attendance'; // Phase 2, locked
  static const all = [home, courses, bus, library, alerts];
}

/// Shows only the signed-in student's own data - profile, their own
/// registered courses, their own bus assignment, their own
/// library records, their own notifications - each as its own page in the
/// same sidebar layout as every other portal.
/// Deliberately excludes everything spec §8 lists as off-limits: other
/// students' data, gate history, the live bus map, and security alerts.
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);

    void openTab(int i) => ref.read(studentPageProvider.notifier).state = StudentPage.all[i];

    return PortalShell(
      roleLabel: 'Student',
      selection: studentPageProvider,
      nav: PortalNav(
        home: PortalItem(
          id: StudentPage.home,
          label: 'Home',
          description: 'Your summary',
          icon: Icons.home_outlined,
          screen: _StudentGate(child: StudentHomeSection(onOpenTab: openTab)),
        ),
        topItems: [
          const PortalItem(
            id: StudentPage.courses,
            label: 'Courses',
            description: 'The courses you are registered in',
            icon: Icons.school_outlined,
            screen: _StudentGate(child: CoursesSection()),
          ),
          const PortalItem(
            id: StudentPage.bus,
            label: 'Bus',
            description: 'Your bus, stop and ETA',
            icon: Icons.directions_bus_filled_outlined,
            screen: _StudentGate(child: BusAssignmentSection()),
          ),
          const PortalItem(
            id: StudentPage.library,
            label: 'Library',
            description: 'Your books, due dates and history',
            icon: Icons.menu_book_outlined,
            screen: _StudentGate(child: LibrarySection()),
          ),
          PortalItem(
            id: StudentPage.alerts,
            label: 'Alerts',
            description: 'Your notifications',
            icon: Icons.notifications_outlined,
            badge: unread,
            screen: const _StudentGate(child: NotificationsSection()),
          ),
        ],
        // Attendance is taken by the iris camera, so it arrives in Phase 2 (a locked menu entry only).
        planned: const PortalGroup(
          id: 'group.phase2',
          label: 'Phase 2',
          description: 'Planned features, not available yet',
          icon: Icons.construction_outlined,
          phase: 2,
          items: [
            PortalItem(
              id: StudentPage.attendance,
              label: 'Attendance',
              description: 'Your attendance in each course',
              icon: Icons.fact_check_outlined,
              phase: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a page only once the student's own record has loaded.
class _StudentGate extends ConsumerWidget {
  final Widget child;
  const _StudentGate({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(studentProfileProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Could not load your profile.\n$err', textAlign: TextAlign.center)),
          data: (student) => student == null
              ? const Center(child: Text('No student record found for this account.'))
              : child,
        );
  }
}
