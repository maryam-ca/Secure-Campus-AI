import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../constants/roles.dart';
import '../theme/app_theme.dart';

class PortalScaffold extends ConsumerWidget {
  final String title;
  final UserRole role;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Runs before signing out and is awaited (errors ignored), so a screen can
  /// finish what it must, e.g. the driver ending a live trip.
  final Future<void> Function()? onBeforeSignOut;

  const PortalScaffold({
    super.key,
    required this.title,
    required this.role,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.onBeforeSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentLightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  role.displayName,
                  style: const TextStyle(color: AppColors.primaryBlueDark, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Change password',
            icon: const Icon(Icons.lock_reset),
            onPressed: () => GoRouter.of(context).push('/change-password'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await onBeforeSignOut?.call();
              } catch (_) {
                // never block signing out
              }
              await ref.read(authServiceProvider).signOut();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// A simple, consistent section container used across dashboards -
/// clean card, soft border, rounded corners (spec §40).
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  const SectionCard({super.key, required this.title, required this.child, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
