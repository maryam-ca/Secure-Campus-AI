import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/roles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/student_providers.dart';
import 'widgets/attendance_section.dart';
import 'widgets/bus_assignment_section.dart';
import 'widgets/library_section.dart';
import 'widgets/notifications_section.dart';

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
  int _tab = 0;

  static const _tabs = [
    AttendanceSection(),
    BusAssignmentSection(),
    LibrarySection(),
    NotificationsSection(),
  ];

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentProfileProvider);

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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ProfileHeader(
                  name: student.name,
                  regNo: student.registrationNumber,
                  program: student.program,
                  semester: student.semester,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.97, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_tab), child: _tabs[_tab]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.directions_bus_filled_outlined), label: 'Bus'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String regNo;
  final String program;
  final int semester;

  const _ProfileHeader({required this.name, required this.regNo, required this.program, required this.semester});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                  const SizedBox(height: 3),
                  Text(regNo, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  Text('$program · Semester $semester', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}