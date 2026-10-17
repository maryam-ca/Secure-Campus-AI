import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/portal_nav.dart';
import '../../core/widgets/portal_shell.dart';
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

/// The Security portal. Phase 1: the lost-card reports (read only). The gate
/// entries and unknown-person alerts need the iris camera (Phase 2); they are
/// only locked menu entries here, with no screen behind them.
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
