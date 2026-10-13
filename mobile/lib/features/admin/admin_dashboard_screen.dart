import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardStatsProvider),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(children: [
          const SizedBox(height: 80),
          Center(child: Text('Could not load dashboard stats.\n$err', textAlign: TextAlign.center)),
        ]),
        data: (stats) => LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 3 : 2);
            final cards = <_StatCard>[
              _StatCard('Total Students', '${stats.totalStudents}', Icons.school_outlined, AppColors.primaryBlue),
              _StatCard("Today's Attendance", '${stats.todayAttendance}', Icons.fact_check_outlined, AppColors.success),
              _StatCard("Today's Gate Entries", '${stats.todayGateEntries}', Icons.login_outlined, AppColors.primaryBlue),
              _StatCard('Unknown Alerts (open)', '${stats.openUnknownAlerts}',
                  Icons.warning_amber_outlined, stats.openUnknownAlerts > 0 ? AppColors.error : AppColors.success),
              _StatCard('Library Books', '${stats.totalBooks}', Icons.menu_book_outlined, AppColors.primaryBlue),
              _StatCard('Issued Books', '${stats.issuedBooks}', Icons.assignment_outlined, AppColors.warning),
              _StatCard('Bus Status', stats.busStatus, Icons.directions_bus_filled_outlined,
                  stats.busStatus.startsWith('Trip') ? AppColors.success : AppColors.bodyText),
            ];
            return GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: cards,
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Text(
              value,
              style: TextStyle(fontSize: value.length > 6 ? 16 : 24, fontWeight: FontWeight.w800, color: AppColors.navyText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
