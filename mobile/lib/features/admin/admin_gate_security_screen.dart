import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/secure_storage_image.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

class AdminGateSecurityScreen extends StatelessWidget {
  const AdminGateSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            color: AppColors.cardBackground,
            child: TabBar(
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.bodyText,
              indicatorColor: AppColors.primaryBlue,
              tabs: [Tab(text: 'Gate Entries'), Tab(text: 'Unknown-Person Alerts')],
            ),
          ),
          Expanded(child: TabBarView(children: [_GateEntriesTab(), _AlertsTab()])),
        ],
      ),
    );
  }
}

class _GateEntriesTab extends ConsumerWidget {
  const _GateEntriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(gateEntriesProvider);
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load gate entries.\n$err')),
      data: (entries) => entries.isEmpty
          ? const Center(child: Text('No gate entries yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final e = entries[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_outlined, color: AppColors.success),
                    title: Text('${e.name} — ${e.registrationNumber}'),
                    subtitle: Text('${e.cameraLocation} · score ${(e.recognitionScore * 100).toStringAsFixed(0)}%'),
                    trailing: Text(e.timestamp != null ? dateFmt.format(e.timestamp!) : '—',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                );
              },
            ),
    );
  }
}

class _AlertsTab extends ConsumerWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(securityAlertsProvider);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load alerts.\n$err')),
      data: (alerts) => alerts.isEmpty
          ? const Center(child: Text('No unknown-person alerts.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _AlertCard(alert: alerts[i], dateFmt: dateFmt),
            ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final SecurityAlertModel alert;
  final DateFormat dateFmt;
  const _AlertCard({required this.alert, required this.dateFmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isResolved = alert.status == SecurityAlertStatus.resolved;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SecureStorageImage(storagePath: alert.imagePath, width: 72, height: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unknown Person Detected', style: Theme.of(context).textTheme.titleMedium),
                  Text(alert.cameraLocation, style: Theme.of(context).textTheme.bodyMedium),
                  Text(alert.createdAt != null ? dateFmt.format(alert.createdAt!) : '—',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isResolved ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(isResolved ? 'RESOLVED' : 'NEW',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: isResolved ? AppColors.success : AppColors.error)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => ref.read(adminRepositoryProvider).setAlertStatus(alert.id, !isResolved),
                        child: Text(isResolved ? 'Mark as new' : 'Mark resolved'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
