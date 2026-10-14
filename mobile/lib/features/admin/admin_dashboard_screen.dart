import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../core/widgets/animated_shield_logo.dart';
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
    final loans = ref.watch(activeIssuesProvider).valueOrNull ?? const <LibrarianIssueRow>[];
    final newReports = (ref.watch(issueReportsProvider).valueOrNull ?? const []).where((r) => r.isOpen).length;
    final counts = catalogCounts(books, loans);
    final name = ref.watch(currentAppUserProvider).valueOrNull?.name;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardStatsProvider),
      child: statsAsync.when(
        loading: () => ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())]),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.bodyText),
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
          final attention = <_AttentionItem>[
            if (stats.openUnknownAlerts > 0)
              _AttentionItem(
                icon: Icons.warning_amber_rounded,
                color: AppColors.error,
                text: '${stats.openUnknownAlerts} unknown-person alert${stats.openUnknownAlerts == 1 ? '' : 's'} to review',
                onTap: () => _open(ref, AdminSection.gateSecurity),
              ),
            if (counts.overdue > 0)
              _AttentionItem(
                icon: Icons.watch_later_outlined,
                color: AppColors.warning,
                text: '${counts.overdue} overdue book${counts.overdue == 1 ? '' : 's'}',
                onTap: () => _open(ref, AdminSection.library),
              ),
            if (newReports > 0)
              _AttentionItem(
                icon: Icons.report_gmailerrorred_outlined,
                color: AppColors.primaryBlue,
                text: '$newReports new student report${newReports == 1 ? '' : 's'} on library issues',
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
                _StatTile(
                  label: 'Total Students',
                  value: '${stats.totalStudents}',
                  icon: Icons.school_outlined,
                  color: AppColors.primaryBlueDark,
                  onTap: () => _open(ref, AdminSection.students),
                ),
                _StatTile(
                  label: 'Attendance',
                  note: 'today',
                  value: '${stats.todayAttendance}',
                  icon: Icons.fact_check_outlined,
                  color: AppColors.success,
                  onTap: () => _open(ref, AdminSection.gateSecurity),
                ),
                _StatTile(
                  label: 'Gate Entries',
                  note: 'today',
                  value: '${stats.todayGateEntries}',
                  icon: Icons.login_outlined,
                  color: AppColors.primaryBlue,
                  onTap: () => _open(ref, AdminSection.gateSecurity),
                ),
                _StatTile(
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
                  _GreetingBanner(name: name),
                  const SizedBox(height: 16),
                  _AttentionPanel(items: attention),
                  const SizedBox(height: 14),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: wide ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 92, // fixed height: text can never overflow
                    ),
                    children: tiles,
                  ),
                  const SizedBox(height: 12),
                  _BusStatusTile(status: stats.busStatus, onTap: () => _open(ref, AdminSection.bus)),
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

class _GreetingBanner extends StatelessWidget {
  final String? name;
  const _GreetingBanner({this.name});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final who = (name == null || name!.trim().isEmpty) ? 'Admin' : name!.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: AppColors.navyText.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // The real SecureCampus mark (same as the login screen), still.
          const AnimatedShieldLogo(size: 46, animate: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SecureCampus',
                  style: TextStyle(color: AppColors.primaryBlue, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_greeting(now)}, $who',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.navyText, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMMM y').format(now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionItem {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
  const _AttentionItem({required this.icon, required this.color, required this.text, required this.onTap});
}

/// Only what needs action, one slim row each. Replaces separate cards for
/// the same numbers, so nothing appears twice.
class _AttentionPanel extends StatelessWidget {
  final List<_AttentionItem> items;
  const _AttentionPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('All clear - nothing needs attention.',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6, left: 2),
          child: Text('Needs attention',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.navyText)),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: item.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.color.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: item.color, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                      Icon(Icons.chevron_right, color: item.color, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String? note; // one short extra line, e.g. "2 issued · 1 locked"
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navyText, height: 1.1)),
                    ),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.bodyText, height: 1.2)),
                    if (note != null)
                      Text(note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600, height: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusStatusTile extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _BusStatusTile({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = status.startsWith('Trip');
    final color = active ? AppColors.success : AppColors.bodyText;

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.directions_bus_filled_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bus Status', style: TextStyle(fontSize: 11.5, color: AppColors.bodyText)),
                    Text(status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: active ? AppColors.success : AppColors.navyText)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.bodyText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
