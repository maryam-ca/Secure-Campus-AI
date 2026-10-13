import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_hero_header.dart';
import '../../../providers/student_providers.dart';

class BusAssignmentSection extends ConsumerWidget {
  const BusAssignmentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(busAssignmentProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeroHeader(
          icon: Icons.directions_bus_filled_outlined,
          title: 'Campus Bus',
          subtitle: 'Your registered stop and live pickup alerts.',
        ),
        const SizedBox(height: 20),
        assignmentAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (_, __) => const Text('Could not load bus assignment.', style: TextStyle(color: AppColors.error)),
          data: (assignment) {
            if (assignment == null) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.navyText.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.bodyText.withValues(alpha: 0.8), size: 20),
                    const SizedBox(width: 10),
                    const Text('Not Assigned', style: TextStyle(color: AppColors.bodyText, fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.navyText.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 14),
                        SizedBox(width: 5),
                        Text('ASSIGNED', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _row('Bus', assignment.busId),
                  _row('Registered Stop', assignment.stopName),
                  const SizedBox(height: 10),
                  Text(
                    "You'll get a notification when the bus is about 10 minutes from your stop.",
                    style: TextStyle(color: AppColors.bodyText, fontSize: 12.5),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.bodyText, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        ],
      ),
    );
  }
}