import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_hero_header.dart';
import '../../../models/dashboard_models.dart';
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
                  const SizedBox(height: 12),
                  BusStatusBanner(assignment: assignment),
                  const SizedBox(height: 12),
                  const Text(
                    "You'll get one alert about 10 minutes before the bus reaches your stop.",
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

/// The bus status as a plain sentence, coloured by urgency. Re-evaluated every
/// 30 seconds so a status that stops being refreshed turns into
/// "No trip in progress" on its own (it is never left saying "on its way").
class BusStatusBanner extends StatefulWidget {
  final BusAssignmentModel assignment;

  /// Injectable clock for tests.
  final DateTime Function() clock;
  const BusStatusBanner({super.key, required this.assignment, this.clock = DateTime.now});

  @override
  State<BusStatusBanner> createState() => _BusStatusBannerState();
}

class _BusStatusBannerState extends State<BusStatusBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.assignment.tripInfo(widget.clock());
    final (color, icon) = switch (info.level) {
      BusTripLevel.headOut => (AppColors.success, Icons.directions_run),
      BusTripLevel.onTheWay => (AppColors.primaryBlue, Icons.directions_bus_filled_outlined),
      BusTripLevel.idle => (AppColors.bodyText, Icons.info_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(info.text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14))),
        ],
      ),
    );
  }
}
