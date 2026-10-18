import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/save_error.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/admin_models.dart';
import '../../models/student_model.dart';
import '../../providers/admin_providers.dart';

/// Admin > Academics > Courses: just the course names, with Add, Edit and
/// Delete. Timetables (weekly schedule) belong to Phase 2 with attendance.
class AdminCoursesScreen extends ConsumerWidget {
  const AdminCoursesScreen({super.key});

  /// Deletes a course after confirming. A course that students are registered
  /// in cannot be deleted: they would keep a course that no longer exists.
  Future<void> _delete(BuildContext context, WidgetRef ref, AdminCourseModel course) async {
    final enrolled = (ref.read(allStudentsProvider).valueOrNull ?? const <StudentModel>[])
        .where((s) => s.courseIds.contains(course.id))
        .length;
    if (enrolled > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot delete this course'),
          content: Text('$enrolled student${enrolled == 1 ? ' is' : 's are'} registered in "${course.name}". '
              'Remove the course from their records first (Students > Edit).'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${course.name}"?',
      message: 'The course is removed. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCourse(course.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    ref.watch(allStudentsProvider); // kept loaded so Delete knows who is registered

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-course'),
        onPressed: () => showDialog(context: context, builder: (_) => const _CourseDialog()),
        icon: const Icon(Icons.add),
        label: const Text('Add Course'),
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load courses.\n$err')),
        data: (courses) => courses.isEmpty
            ? const Center(child: Text('No courses yet. Tap "Add Course".'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = courses[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined, color: AppColors.primaryBlue),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('course-edit-${c.id}'),
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => showDialog(context: context, builder: (_) => _CourseDialog(existing: c)),
                          ),
                          IconButton(
                            key: Key('course-delete-${c.id}'),
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                            onPressed: () => _delete(context, ref, c),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final _idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$');

class _CourseDialog extends ConsumerStatefulWidget {
  final AdminCourseModel? existing;
  const _CourseDialog({this.existing});

  @override
  ConsumerState<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends ConsumerState<_CourseDialog> {
  late final TextEditingController _id = TextEditingController(text: widget.existing?.id ?? '');
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  String? _idError;
  String? _nameError;
  String? _saveError;
  bool _busy = false;

  bool get _isEditing => widget.existing != null;

  Future<void> _save() async {
    final id = _id.text.trim();
    final name = _name.text.trim();
    final idError = (!_isEditing && !_idPattern.hasMatch(id))
        ? 'Letters, numbers, - or _ only, up to 20 characters (e.g. SE)'
        : null;
    final nameError = (name.length < 2 || name.length > 120) ? 'Enter the course name (2 to 120 characters)' : null;
    if (idError != null || nameError != null) {
      setState(() {
        _idError = idError;
        _nameError = nameError;
        _saveError = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      await ref.read(adminRepositoryProvider).upsertCourse(AdminCourseModel(id: widget.existing?.id ?? id, name: name));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = saveFailureMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Course' : 'Add Course'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('course-id-field'),
              controller: _id,
              enabled: !_isEditing,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'Course ID (e.g. SE)', errorText: _idError),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('course-name-field'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Course name', errorText: _nameError),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 10),
              Text(_saveError!, key: const Key('course-save-error'), style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
