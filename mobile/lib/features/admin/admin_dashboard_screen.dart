import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../core/widgets/dashboard_widgets.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_navigation_provider.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_report_providers.dart';
import '../../providers/librarian_providers.dart';

/// Admin home - one screen, no scrolling on a normal phone.
///
/// A short greeting, what needs attention right now (only when there is
/// something), and five key numbers. Every item is tappable and opens its
/// section. Nothing is shown twice: alerts and overdue books live in the
/// attention list, not in extra cards.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _open(WidgetRef ref, int section, {int libraryTab = 0}) {
    ref.read(adminLibraryTabProvider.notifier).state = libraryTab;
    ref.read(adminSectionProvider.notifier).state = section;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    // Optional extras: if these fail to load the dashboard still works.
    final books = ref.watch(booksProvider).valueOrNull ?? const <BookModel>[];
    final loans =
        ref.watch(activeIssuesProvider).valueOrNull ??
        const <LibrarianIssueRow>[];
    final newReports = (ref.watch(issueReportsProvider).valueOrNull ?? const [])
        .where((r) => r.isOpen)
        .length;
    final counts = catalogCounts(books, loans);
    final name = ref.watch(currentAppUserProvider).valueOrNull?.name;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardStatsProvider),
      child: statsAsync.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.bodyText,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load the dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check your connection and pull down to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.bodyText),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => ref.invalidate(dashboardStatsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (stats) {
          final attention = <AttentionItem>[
            if (stats.openUnknownAlerts > 0)
              AttentionItem(
                icon: Icons.warning_amber_rounded,
                color: AppColors.error,
                text:
                    '${stats.openUnknownAlerts} unknown-person alert${stats.openUnknownAlerts == 1 ? '' : 's'} to review',
                onTap: () => _open(ref, AdminSection.gateSecurity),
              ),
            if (counts.overdue > 0)
              AttentionItem(
                icon: Icons.watch_later_outlined,
                color: AppColors.warning,
                text:
                    '${counts.overdue} overdue book${counts.overdue == 1 ? '' : 's'}',
                onTap: () => _open(ref, AdminSection.library),
              ),
            if (newReports > 0)
              AttentionItem(
                icon: Icons.report_gmailerrorred_outlined,
                color: AppColors.primaryBlue,
                text:
                    '$newReports new student report${newReports == 1 ? '' : 's'} on library issues',
                onTap: () => _open(ref, AdminSection.library, libraryTab: 1),
              ),
          ];

          final libraryNote = [
            '${stats.issuedBooks} issued',
            if (counts.locked > 0) '${counts.locked} locked',
          ].join(' · ');

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 600;

              final tiles = <Widget>[
                StatTile(
                  label: 'Total Students',
                  value: '${stats.totalStudents}',
                  icon: Icons.school_outlined,
                  color: AppColors.primaryBlueDark,
                  onTap: () => _open(ref, AdminSection.students),
                ),
                StatTile(
                  label: 'Attendance',
                  note: 'today',
                  value: '${stats.todayAttendance}',
                  icon: Icons.fact_check_outlined,
                  color: AppColors.success,
                  onTap: () => _open(ref, AdminSection.gateSecurity),
                ),
                StatTile(
                  label: 'Gate Entries',
                  note: 'today',
                  value: '${stats.todayGateEntries}',
                  icon: Icons.login_outlined,
                  color: AppColors.primaryBlue,
                  onTap: () => _open(ref, AdminSection.gateSecurity),
                ),
                StatTile(
                  label: 'Library Books',
                  note: libraryNote,
                  value: '${stats.totalBooks}',
                  icon: Icons.menu_book_outlined,
                  color: AppColors.warning,
                  onTap: () => _open(ref, AdminSection.library),
                ),
              ];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  BrandHeaderCard(
                    title:
                        '${_greeting(DateTime.now())}, ${(name == null || name.trim().isEmpty) ? 'Admin' : name.trim()}',
                    subtitle: DateFormat(
                      'EEEE, d MMMM y',
                    ).format(DateTime.now()),
                  ),
                  const SizedBox(height: 16),
                  AttentionPanel(items: attention),
                  const SizedBox(height: 14),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: wide ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent:
                          92, // fixed height: text can never overflow
                    ),
                    children: tiles,
                  ),
                  const SizedBox(height: 12),
                  WideStatusTile(
                    icon: Icons.directions_bus_filled_outlined,
                    label: 'Bus Status',
                    text: stats.busStatus,
                    color: stats.busStatus.startsWith('Trip')
                        ? AppColors.success
                        : AppColors.bodyText,
                    onTap: () => _open(ref, AdminSection.bus),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
