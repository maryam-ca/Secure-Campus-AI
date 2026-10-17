import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dashboard_widgets.dart';
import '../../../models/dashboard_models.dart';
import '../../../providers/student_providers.dart';

/// Tab indexes of the student dashboard (so the Home tiles can jump to them).
class StudentTab {
  StudentTab._();
  static const home = 0;
  static const courses = 1;
  static const bus = 2;
  static const library = 3;
  static const alerts = 4;
}

/// The student's one-screen summary: who they are, what needs attention
/// (overdue or soon-due books, unread alerts, the bus being close), and four
/// key numbers. Everything opens the matching tab.
class StudentHomeSection extends ConsumerWidget {
  final void Function(int tab) onOpenTab;

  /// Injectable so tests can fix "now".
  final DateTime? now;
  const StudentHomeSection({super.key, required this.onOpenTab, this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = now ?? DateTime.now();
    final student = ref.watch(studentProfileProvider).valueOrNull;
    final issues = ref.watch(libraryIssuesProvider).valueOrNull ?? const <LibraryIssueModel>[];
    final unread = ref.watch(unreadNotificationsCountProvider);
    final bus = ref.watch(busAssignmentProvider).valueOrNull;

    final active = issues.where((i) => i.status != LibraryIssueStatus.returned).toList();
    final overdue = active.where((i) => i.status == LibraryIssueStatus.overdue).length;
    final dueSoon = active.where((i) => i.status == LibraryIssueStatus.issued && i.daysUntilDue(today) <= 2).length;
    final trip = bus?.tripInfo(today);

    final attention = <AttentionItem>[
      if (overdue > 0)
        AttentionItem(
          icon: Icons.watch_later_outlined,
          color: AppColors.error,
          text: '$overdue book${overdue == 1 ? ' is' : 's are'} overdue - please return ${overdue == 1 ? 'it' : 'them'}',
          onTap: () => onOpenTab(StudentTab.library),
        ),
      if (dueSoon > 0)
        AttentionItem(
          icon: Icons.event_outlined,
          color: AppColors.warning,
          text: '$dueSoon book${dueSoon == 1 ? '' : 's'} due within 2 days',
          onTap: () => onOpenTab(StudentTab.library),
        ),
      if (trip != null && (trip.level == BusTripLevel.getReady || trip.level == BusTripLevel.headOut))
        AttentionItem(
          icon: Icons.directions_bus_filled_outlined,
          color: trip.level == BusTripLevel.headOut ? AppColors.success : AppColors.warning,
          text: 'Bus: ${trip.text}',
          onTap: () => onOpenTab(StudentTab.bus),
        ),
      if (unread > 0)
        AttentionItem(
          icon: Icons.notifications_active_outlined,
          color: AppColors.primaryBlue,
          text: '$unread unread alert${unread == 1 ? '' : 's'}',
          onTap: () => onOpenTab(StudentTab.alerts),
        ),
    ];

    final nextDue = active.where((i) => i.status == LibraryIssueStatus.issued).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        BrandHeaderCard(
          title: student?.name ?? 'My Campus',
          subtitle: student == null
              ? ''
              : '${student.registrationNumber} · ${student.program} · Semester ${student.semester}',
        ),
        const SizedBox(height: 16),
        AttentionPanel(items: attention),
        const SizedBox(height: 14),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 92,
          ),
          children: [
            // Attendance comes from the iris camera (Phase 2): no number yet.
            const PlannedTile(label: 'Attendance', icon: Icons.fact_check_outlined),
            StatTile(
              label: 'Books issued',
              value: '${active.length}',
              note: overdue > 0
                  ? '$overdue overdue'
                  : nextDue.isNotEmpty
                      ? 'next due ${DateFormat('d MMM').format(nextDue.first.expiryDate)}'
                      : 'none due',
              noteColor: overdue > 0 ? AppColors.error : null,
              icon: Icons.menu_book_outlined,
              color: AppColors.warning,
              onTap: () => onOpenTab(StudentTab.library),
            ),
            StatTile(
              label: 'Unread alerts',
              value: '$unread',
              icon: Icons.notifications_outlined,
              color: AppColors.primaryBlue,
              onTap: () => onOpenTab(StudentTab.alerts),
            ),
            StatTile(
              label: 'Courses',
              value: '${student?.courseIds.length ?? 0}',
              icon: Icons.school_outlined,
              color: AppColors.primaryBlueDark,
              onTap: () => onOpenTab(StudentTab.courses),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WideStatusTile(
          icon: Icons.directions_bus_filled_outlined,
          label: bus == null ? 'Campus Bus' : 'Campus Bus - ${bus.stopName}',
          text: bus == null ? 'You are not assigned to a bus.' : trip!.text,
          color: switch (trip?.level) {
            BusTripLevel.headOut => AppColors.success,
            BusTripLevel.getReady => AppColors.warning,
            BusTripLevel.onTheWay => AppColors.primaryBlue,
            _ => AppColors.bodyText,
          },
          onTap: () => onOpenTab(StudentTab.bus),
        ),
      ],
    );
  }
}
