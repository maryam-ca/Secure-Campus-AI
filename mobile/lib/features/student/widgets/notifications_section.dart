import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/tab_hero_header.dart';
import '../../../models/dashboard_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_providers.dart';

IconData iconForNotificationType(String type) {
  switch (type) {
    case 'LOST_CARD':
      return Icons.badge_outlined;
    case 'LIBRARY_OVERDUE':
      return Icons.menu_book_outlined;
    case 'BUS_10_MIN':
      return Icons.directions_bus_filled_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This removes every notification in this list. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(studentRepositoryProvider).clearAllNotifications(uid);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(studentNotificationsProvider);
    final appUser = ref.watch(currentAppUserProvider).value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeroHeader(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Library reminders, bus alerts, and lost-card matches.',
        ),
        const SizedBox(height: 14),
        notificationsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (_, __) => const Text('Could not load notifications.', style: TextStyle(color: AppColors.error)),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No notifications yet.', style: TextStyle(color: AppColors.bodyText));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (appUser != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: PressableScale(
                      onTap: () => _confirmClearAll(context, ref, appUser.uid),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_sweep_outlined, size: 15, color: AppColors.error),
                            SizedBox(width: 5),
                            Text('Clear all', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                ...items.map((n) => _NotificationTile(notification: n)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('dd MMM, hh:mm a');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead ? AppColors.cardBackground : AppColors.accentLightBlue.withValues(alpha: 0.4),
          border: Border.all(color: notification.isRead ? AppColors.divider : AppColors.primaryBlue.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: AppColors.navyText.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PressableScale(
              onTap: notification.isRead
                  ? null
                  : () => ref.read(studentRepositoryProvider).markNotificationRead(notification.id),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(iconForNotificationType(notification.type), size: 20, color: AppColors.primaryBlueDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notification.message, style: TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      dateFmt.format(notification.createdAt!),
                      style: TextStyle(fontSize: 11, color: AppColors.bodyText.withValues(alpha: 0.65)),
                    ),
                  ],
                ],
              ),
            ),
            PressableScale(
              onTap: () => ref.read(studentRepositoryProvider).deleteNotification(notification.id),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppColors.bodyText.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.close, size: 16, color: AppColors.bodyText.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}