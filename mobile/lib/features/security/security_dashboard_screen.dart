import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/roles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../core/widgets/secure_storage_image.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

class SecurityDashboardScreen extends StatelessWidget {
  const SecurityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PortalScaffold(
        title: 'Security',
        role: UserRole.security,
        body: Column(
          children: [
            const Material(
              color: AppColors.cardBackground,
              child: TabBar(
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: AppColors.bodyText,
                indicatorColor: AppColors.primaryBlue,
                tabs: [Tab(text: 'Recent Entries'), Tab(text: 'Unknown-Person Alerts')],
              ),
            ),
            const Expanded(child: TabBarView(children: [_RecentEntries(), _Alerts()])),
          ],
        ),
      ),
    );
  }
}

class _RecentEntries extends ConsumerWidget {
  const _RecentEntries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(gateEntriesProvider);
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load gate entries.\n$err')),
      data: (entries) => entries.isEmpty
          ? const Center(child: Text('No verified entries yet.'))
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

class _Alerts extends ConsumerStatefulWidget {
  const _Alerts();

  @override
  ConsumerState<_Alerts> createState() => _AlertsState();
}

enum _AlertFilter { all, newOnly, resolved }

class _AlertsState extends ConsumerState<_Alerts> {
  _AlertFilter _filter = _AlertFilter.all;

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(securityAlertsProvider);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              ChoiceChip(label: const Text('All'), selected: _filter == _AlertFilter.all, onSelected: (_) => setState(() => _filter = _AlertFilter.all)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('New'), selected: _filter == _AlertFilter.newOnly, onSelected: (_) => setState(() => _filter = _AlertFilter.newOnly)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Resolved'), selected: _filter == _AlertFilter.resolved, onSelected: (_) => setState(() => _filter = _AlertFilter.resolved)),
            ],
          ),
        ),
        Expanded(
          child: alertsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Could not load alerts.\n$err')),
            data: (allAlerts) {
              final alerts = switch (_filter) {
                _AlertFilter.all => allAlerts,
                _AlertFilter.newOnly => allAlerts.where((a) => a.status == SecurityAlertStatus.newAlert).toList(),
                _AlertFilter.resolved => allAlerts.where((a) => a.status == SecurityAlertStatus.resolved).toList(),
              };
              if (alerts.isEmpty) return const Center(child: Text('No alerts match this filter.'));
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _AlertCard(alert: alerts[i], dateFmt: dateFmt),
              );
            },
          ),
        ),
      ],
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
            SecureStorageImage(storagePath: alert.imagePath, width: 80, height: 80),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UNKNOWN PERSON DETECTED', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.error)),
                  Text(alert.cameraLocation, style: Theme.of(context).textTheme.bodyMedium),
                  Text(alert.createdAt != null ? dateFmt.format(alert.createdAt!) : '—',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
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
                      ElevatedButton(
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
