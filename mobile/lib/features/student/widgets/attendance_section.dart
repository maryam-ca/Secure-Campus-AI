import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_hero_header.dart';
import '../../../providers/student_providers.dart';
import 'course_attendance_card.dart';

class AttendanceSection extends ConsumerWidget {
  const AttendanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(studentCoursesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeroHeader(
          icon: Icons.fact_check_outlined,
          title: 'Course Attendance',
          subtitle: 'Live percentages, computed from real class records.',
        ),
        const SizedBox(height: 20),
        coursesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (_, __) => const Text('Could not load courses.', style: TextStyle(color: AppColors.error)),
          data: (courses) {
            if (courses.isEmpty) {
              return const Text('No registered courses yet.', style: TextStyle(color: AppColors.bodyText));
            }
            return Column(children: courses.map((c) => CourseAttendanceCard(course: c)).toList());
          },
        ),
      ],
    );
  }
}