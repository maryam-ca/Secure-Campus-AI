import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/portal_nav.dart';
import '../../core/widgets/portal_shell.dart';
import '../../core/widgets/secure_storage_image.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

/// Which page of the Security portal is open.
final securityPageProvider = StateProvider<String>((ref) => SecurityPage.lostCards);

class SecurityPage {
  SecurityPage._();
  static const lostCards = 'lost-cards';
  static const entries = 'entries';
  static const alerts = 'alerts';
}

/// The Security portal. Phase 1: the lost-card reports (read only). Phase 2,
/// locked until the iris camera runs: gate entries and unknown-person alerts.
/// To switch a Phase 2 page on, give its item a `screen`
/// ([RecentEntriesView] / [UnknownAlertsView] are ready).
class SecurityDashboardScreen extends ConsumerWidget {
  const SecurityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In-app notification: the sidebar shows how many found-card reports are
    // still open, live.
    final openCards = (ref.watch(securityLostCardsProvider).valueOrNull ?? const <LostCardReportModel>[])
        .where((r) => !r.isResolved)
        .length;

    return PortalShell(
      roleLabel: 'Security',
      selection: securityPageProvider,
      nav: PortalNav(
        home: PortalItem(
          id: SecurityPage.lostCards,
          label: 'Lost Cards',
          description: 'Student cards found on campus, until Admin resolves them',
          icon: Icons.badge_outlined,
          badge: openCards,
          screen: const LostCardsView(),
        ),
        planned: const PortalGroup(
          id: 'group.phase2',
          label: 'Phase 2',
          description: 'Gate & Security: planned, not available yet',
          icon: Icons.construction_outlined,
          phase: 2,
          items: [
            PortalItem(
              id: SecurityPage.entries,
              label: 'Gate Entries',
              description: 'Latest people recognised at the gate',
              icon: Icons.login_outlined,
              phase: 2,
            ),
            PortalItem(
              id: SecurityPage.alerts,
              label: 'Unknown-Person Alerts',
              description: 'People at the gate the system did not recognise',
              icon: Icons.warning_amber_rounded,
              phase: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class RecentEntriesView extends ConsumerWidget {
  const RecentEntriesView({super.key});

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

class UnknownAlertsView extends ConsumerStatefulWidget {
  const UnknownAlertsView({super.key});

  @override
  ConsumerState<UnknownAlertsView> createState() => _AlertsState();
}

enum _AlertFilter { all, newOnly, resolved }

class _AlertsState extends ConsumerState<UnknownAlertsView> {
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

/// One unknown-person alert, read only. Only Admin resolves an alert; Security
/// sees its status change from NEW to RESOLVED.
class _AlertCard extends StatelessWidget {
  final SecurityAlertModel alert;
  final DateFormat dateFmt;
  const _AlertCard({required this.alert, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
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


/// Found-card reports, read only. Open ones stay until Admin resolves them;
/// a resolved one shows "Resolved" for a day and then disappears.
class LostCardsView extends ConsumerWidget {
  const LostCardsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return ref.watch(securityLostCardsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Could not load lost-card reports.\n$err')),
          data: (reports) => reports.isEmpty
              ? const Center(child: Text('No lost-card reports.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final r = reports[i];
                    return Card(
                      key: ValueKey('lost-${r.id}'),
                      child: ListTile(
                        leading: Icon(
                          r.isResolved ? Icons.check_circle_outline : Icons.badge_outlined,
                          color: r.isResolved ? AppColors.success : AppColors.warning,
                        ),
                        title: Text('${r.studentNameGuess} - ${r.registrationNumberGuess}'),
                        subtitle: Text('Found at: ${r.location}'
                            '${r.createdAt != null ? ' - ${dateFmt.format(r.createdAt!)}' : ''}'),
                        trailing: Text(
                          r.isResolved ? 'Resolved' : 'Open',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: r.isResolved ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
  }
}
