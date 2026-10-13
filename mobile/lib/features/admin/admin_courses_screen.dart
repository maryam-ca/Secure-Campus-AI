import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class AdminCoursesScreen extends ConsumerWidget {
  const AdminCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => const _CourseDialog()),
        icon: const Icon(Icons.add),
        label: const Text('Add Course'),
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load courses.\n$err')),
        data: (courses) => courses.isEmpty
            ? const Center(child: Text('No courses yet.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = courses[i];
                  return Card(
                    child: ListTile(
                      title: Text(c.name),
                      subtitle: Text(
                        c.cameraId.isEmpty
                            ? 'No camera assigned - attendance detection inactive for this course'
                            : 'Camera: ${c.cameraId} · ${c.schedule.length} scheduled session(s)/week',
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => showDialog(context: context, builder: (_) => _CourseDialog(existing: c)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CourseDialog extends ConsumerStatefulWidget {
  final AdminCourseModel? existing;
  const _CourseDialog({this.existing});

  @override
  ConsumerState<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends ConsumerState<_CourseDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _cameraId;
  late List<ScheduleSlot> _slots;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = TextEditingController(text: e?.id ?? '');
    _name = TextEditingController(text: e?.name ?? '');
    _cameraId = TextEditingController(text: e?.cameraId ?? '');
    _slots = List.of(e?.schedule ?? const []);
  }

  void _addSlot() {
    setState(() => _slots.add(const ScheduleSlot(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00')));
  }

  Future<void> _submit() async {
    if (_id.text.trim().isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).upsertCourse(AdminCourseModel(
            id: _id.text.trim(),
            name: _name.text.trim(),
            cameraId: _cameraId.text.trim(),
            schedule: _slots,
          ));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Course' : 'Add Course'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _id,
                enabled: !isEditing,
                decoration: const InputDecoration(labelText: 'Course ID (e.g. SE)'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Course name')),
              const SizedBox(height: 10),
              TextField(
                controller: _cameraId,
                decoration: const InputDecoration(
                  labelText: 'Camera ID (must match CAMERA_NAME in iris_ai .env)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Weekly schedule', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(onPressed: _addSlot, icon: const Icon(Icons.add, size: 18), label: const Text('Add slot')),
                ],
              ),
              for (int i = 0; i < _slots.length; i++) _SlotEditor(
                slot: _slots[i],
                onChanged: (updated) => setState(() => _slots[i] = updated),
                onRemove: () => setState(() => _slots.removeAt(i)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _SlotEditor extends StatelessWidget {
  final ScheduleSlot slot;
  final ValueChanged<ScheduleSlot> onChanged;
  final VoidCallback onRemove;
  const _SlotEditor({required this.slot, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: slot.dayOfWeek,
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => onChanged(ScheduleSlot(dayOfWeek: v!, startTime: slot.startTime, endTime: slot.endTime)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              initialValue: slot.startTime,
              decoration: const InputDecoration(labelText: 'Start (HH:MM)'),
              onChanged: (v) => onChanged(ScheduleSlot(dayOfWeek: slot.dayOfWeek, startTime: v, endTime: slot.endTime)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              initialValue: slot.endTime,
              decoration: const InputDecoration(labelText: 'End (HH:MM)'),
              onChanged: (v) => onChanged(ScheduleSlot(dayOfWeek: slot.dayOfWeek, startTime: slot.startTime, endTime: v)),
            ),
          ),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close, size: 18, color: AppColors.error)),
        ],
      ),
    );
  }
}
