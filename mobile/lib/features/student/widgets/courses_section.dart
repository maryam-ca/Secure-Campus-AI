import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_hero_header.dart';
import '../../../providers/student_providers.dart';

/// The courses the signed-in student is registered in (their own list only).
class CoursesSection extends ConsumerWidget {
  const CoursesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(studentCoursesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeroHeader(
          icon: Icons.school_outlined,
          title: 'My Courses',
          subtitle: 'The courses you are registered in this semester.',
        ),
        const SizedBox(height: 20),
        coursesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (_, __) => const Text('Could not load courses.', style: TextStyle(color: AppColors.error)),
          data: (courses) {
            if (courses.isEmpty) {
              return const Text('No registered courses yet.', style: TextStyle(color: AppColors.bodyText));
            }
            return Column(
              children: [
                for (final c in courses)
                  Card(
                    child: ListTile(
                      key: ValueKey('course-${c.id}'),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.accentLightBlue,
                        child: Icon(Icons.menu_book_outlined, color: AppColors.primaryBlueDark, size: 20),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(c.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
