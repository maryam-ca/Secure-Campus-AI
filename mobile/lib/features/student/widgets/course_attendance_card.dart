import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/course_model.dart';
import '../../../providers/student_providers.dart';

class CourseAttendanceCard extends ConsumerWidget {
  final CourseModel course;

  const CourseAttendanceCard({super.key, required this.course});

  Color _colorForPercentage(double pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 65) return AppColors.warning;
    return AppColors.error;
  }

  Widget _icon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: color),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(courseAttendanceProvider(course));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.navyText.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: summaryAsync.when(
          loading: () => Row(
            children: [
              _icon(Icons.menu_book_outlined, AppColors.primaryBlue),
              const SizedBox(width: 12),
              Expanded(child: Text(course.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          error: (err, _) => Row(
            children: [
              _icon(Icons.menu_book_outlined, AppColors.primaryBlue),
              const SizedBox(width: 12),
              Expanded(child: Text(course.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            ],
          ),
          data: (summary) {
            final color = _colorForPercentage(summary.percentage);
            final progress = summary.totalSessions == 0 ? 0.0 : summary.present / summary.totalSessions;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _icon(Icons.menu_book_outlined, color),
                    const SizedBox(width: 12),
                    Expanded(child: Text(course.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${summary.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: AppColors.divider,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.totalSessions == 0
                      ? 'No classes recorded yet for this course'
                      : 'Present ${summary.present} of ${summary.totalSessions} classes  ·  Absent ${summary.absent}',
                  style: TextStyle(color: AppColors.bodyText, fontSize: 12.5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}