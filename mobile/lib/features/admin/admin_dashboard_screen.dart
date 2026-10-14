import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_navigation_provider.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_report_providers.dart';
import '../../providers/librarian_providers.dart';

/// Admin home: a greeting, what needs attention right now, then the key
/// numbers grouped by area. Everything is tappable and opens its section.
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 3 : 2);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _GreetingBanner(name: name),
                  const SizedBox(height: 18),
                  _AttentionPanel(items: attention),
                  const SizedBox(height: 22),
                  _QuickActions(
                    actions: [
                      _QuickAction(Icons.school_outlined, 'Students', () => _open(ref, AdminSection.students)),
                      _QuickAction(Icons.local_library_outlined, 'Library', () => _open(ref, AdminSection.library)),
                      _QuickAction(Icons.shield_outlined, 'Security', () => _open(ref, AdminSection.gateSecurity)),
                      _QuickAction(Icons.videocam_outlined, 'Camera', () => _open(ref, AdminSection.camera)),
                    ],
                  ),
                  _Section(
                    title: 'Campus today',
                    cols: cols,
                    tiles: [
                      _StatTile(
                        label: "Today's Attendance",
                        value: '${stats.todayAttendance}',
                        icon: Icons.fact_check_outlined,
                        color: AppColors.success,
                        onTap: () => _open(ref, AdminSection.gateSecurity),
                      ),
                      _StatTile(
                        label: "Today's Gate Entries",
                        value: '${stats.todayGateEntries}',
                        icon: Icons.login_outlined,
                        color: AppColors.primaryBlue,
                        onTap: () => _open(ref, AdminSection.gateSecurity),
                      ),
                      _StatTile(
                        label: 'Total Students',
                        value: '${stats.totalStudents}',
                        icon: Icons.school_outlined,
                        color: AppColors.primaryBlueDark,
                        onTap: () => _open(ref, AdminSection.students),
                      ),
                      _StatTile(
                        label: 'Unknown Alerts (open)',
                        value: '${stats.openUnknownAlerts}',
                        icon: Icons.warning_amber_outlined,
                        color: stats.openUnknownAlerts > 0 ? AppColors.error : AppColors.success,
                        onTap: () => _open(ref, AdminSection.gateSecurity),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Library',
                    cols: cols,
                    tiles: [
                      _StatTile(
                        label: 'Library Books',
                        value: '${stats.totalBooks}',
                        icon: Icons.menu_book_outlined,
                        color: AppColors.primaryBlue,
                        onTap: () => _open(ref, AdminSection.library),
                      ),
                      _StatTile(
                        label: 'Issued Books',
                        value: '${stats.issuedBooks}',
                        icon: Icons.assignment_outlined,
                        color: AppColors.warning,
                        onTap: () => _open(ref, AdminSection.library),
                      ),
                      _StatTile(
                        label: 'Overdue Books',
                        value: '${counts.overdue}',
                        icon: Icons.watch_later_outlined,
                        color: counts.overdue > 0 ? AppColors.error : AppColors.success,
                        onTap: () => _open(ref, AdminSection.library),
                      ),
                      _StatTile(
                        label: 'Locked Books',
                        value: '${counts.locked}',
                        icon: Icons.lock_outline,
                        color: AppColors.locked,
                        onTap: () => _open(ref, AdminSection.library),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Transport',
                    cols: 1,
                    tiles: [
                      _BusStatusTile(status: stats.busStatus, onTap: () => _open(ref, AdminSection.bus)),
                    ],
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

class _GreetingBanner extends StatelessWidget {
  final String? name;
  const _GreetingBanner({this.name});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final who = (name == null || name!.trim().isEmpty) ? 'Admin' : name!.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyText, AppColors.primaryBlueDark, AppColors.primaryBlue],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlueDark.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting(now)},',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        DateFormat('EEEE, d MMMM y').format(now),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
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

class _AttentionPanel extends StatelessWidget {
  final List<_AttentionItem> items;
  const _AttentionPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success),
            SizedBox(width: 10),
            Expanded(
              child: Text('All clear - nothing needs attention right now.',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8, left: 2),
          child: Text('Needs attention', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navyText)),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: item.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: item.color.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.text,
                            style: TextStyle(color: item.color, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Icon(Icons.chevron_right, color: item.color),
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

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
}

class _QuickActions extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActions({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: a.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Icon(a.icon, color: AppColors.primaryBlue, size: 24),
                      const SizedBox(height: 6),
                      Text(a.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navyText)),
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

class _Section extends StatelessWidget {
  final String title;
  final int cols;
  final List<Widget> tiles;
  const _Section({required this.title, required this.cols, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 24, 0, 10),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navyText)),
        ),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 92, // fixed height: text can never overflow the card
          ),
          children: tiles,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [BoxShadow(color: AppColors.navyText.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.bodyText, height: 1.2)),
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.directions_bus_filled_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bus Status', style: TextStyle(fontSize: 12, color: AppColors.bodyText)),
                    const SizedBox(height: 2),
                    Text(status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: active ? AppColors.success : AppColors.navyText)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.bodyText),
            ],
          ),
        ),
      ),
    );
  }
}
