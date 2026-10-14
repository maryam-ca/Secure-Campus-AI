import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/student_model.dart';
import '../../providers/admin_providers.dart';
import '../../services/backend_api_service.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  List<StudentModel> _filter(List<StudentModel> students) {
    if (_query.isEmpty) return students;
    final q = _query.toLowerCase();
    return students
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.registrationNumber.toLowerCase().contains(q) ||
            s.program.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddStudentDialog(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, registration number, or program',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Could not load students.\n$err', textAlign: TextAlign.center)),
              data: (allStudents) {
                if (allStudents.isEmpty) {
                  return const Center(child: Text('No students yet. Tap "Add Student" to create one.'));
                }
                final students = _filter(allStudents);
                if (students.isEmpty) {
                  return const Center(child: Text('No students match your search.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentLightBlue,
                          child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primaryBlueDark, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(s.name),
                        subtitle: Text('${s.registrationNumber} · ${s.program}, Sem ${s.semester}'
                            '${s.irisEnrolled ? '' : '  ·  Iris NOT enrolled'}'),
                        trailing: s.irisEnrolled
                            ? const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 20)
                            : const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 20),
                        onTap: () => _openStudentDetailSheet(context, ref, s),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddStudentDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const _AddStudentDialog());
  }

  void _openStudentDetailSheet(BuildContext context, WidgetRef ref, StudentModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StudentDetailSheet(student: student),
    );
  }
}

class _AddStudentDialog extends ConsumerStatefulWidget {
  const _AddStudentDialog();

  @override
  ConsumerState<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends ConsumerState<_AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _regNo = TextEditingController();
  final _program = TextEditingController(text: 'BSE');
  final _semester = TextEditingController(text: '1');
  final Set<String> _selectedCourses = {};
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(courseOptionsProvider);

    return AlertDialog(
      title: const Text('Add Student'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _regNo,
                  decoration: const InputDecoration(labelText: 'Registration number (e.g. FA23-BSE-011)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(controller: _program, decoration: const InputDecoration(labelText: 'Program')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _semester,
                        decoration: const InputDecoration(labelText: 'Semester'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: Text('Courses', style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 6),
                coursesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Could not load courses.'),
                  data: (courses) => Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: courses
                        .map((c) => FilterChip(
                              label: Text(c.name),
                              selected: _selectedCourses.contains(c.id),
                              onSelected: (sel) => setState(() {
                                sel ? _selectedCourses.add(c.id) : _selectedCourses.remove(c.id);
                              }),
                            ))
                        .toList(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref.read(backendApiServiceProvider).createAccount(
            email: _email.text.trim(),
            name: _name.text.trim(),
            role: 'student',
            studentFields: {
              'registrationNumber': _regNo.text.trim(),
              'program': _program.text.trim(),
              'semester': int.tryParse(_semester.text.trim()) ?? 1,
              'courses': _selectedCourses.toList(),
            },
            // no password: the server generates a random temporary one,
            // and the student must replace it at first login
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showCredentialsDialog(context, result);
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showCredentialsDialog(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Student account created'),
        content: SelectableText(
          'Email: ${result['email']}\nTemporary password: ${result['temporaryPassword']}\n\n'
          'Give this to the student privately. They will be asked to choose '
          'their own password the first time they sign in. If they forget it, '
          'Admin can reset it from this screen.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _regNo.dispose();
    _program.dispose();
    _semester.dispose();
    super.dispose();
  }
}

class _StudentDetailSheet extends ConsumerStatefulWidget {
  final StudentModel student;
  const _StudentDetailSheet({required this.student});

  @override
  ConsumerState<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends ConsumerState<_StudentDetailSheet> {
  bool _busy = false;
  String? _message;

  Future<void> _enrollIris() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref.read(backendApiServiceProvider).enrollIris(
            studentId: widget.student.uid,
            imageFile: File(picked.path),
          );
      setState(() => _message = result['success'] == true
          ? 'Iris enrolled successfully.'
          : 'Enrollment did not succeed: ${result['reason']}');
    } on BackendApiException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(bool active) async {
    if (!active) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Deactivate this student?',
        message: '${widget.student.name} will lose access to SecureCampus immediately. '
            'You can reactivate them later from this same screen.',
        confirmLabel: 'Deactivate',
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setAccountActive(widget.student.uid, active);
      setState(() => _message = active ? 'Account reactivated.' : 'Account deactivated.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${s.registrationNumber} · ${s.email}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                s.irisEnrolled ? Icons.verified_user_outlined : Icons.warning_amber_outlined,
                color: s.irisEnrolled ? AppColors.success : AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(s.irisEnrolled ? 'Iris enrolled' : 'Iris not yet enrolled'),
            ],
          ),
          const SizedBox(height: 16),
          if (_message != null) ...[
            Text(_message!, style: const TextStyle(color: AppColors.primaryBlueDark)),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        showDialog(context: context, builder: (_) => _EditStudentDialog(student: widget.student));
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _enrollIris,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(s.irisEnrolled ? 'Re-enroll Iris' : 'Enroll Iris'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _toggleActive(false),
                icon: const Icon(Icons.block, color: AppColors.error),
                label: const Text('Deactivate', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          if (_busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
        ],
      ),
    );
  }
}

class _EditStudentDialog extends ConsumerStatefulWidget {
  final StudentModel student;
  const _EditStudentDialog({required this.student});

  @override
  ConsumerState<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends ConsumerState<_EditStudentDialog> {
  late final TextEditingController _name;
  late final TextEditingController _program;
  late final TextEditingController _semester;
  late final TextEditingController _newPassword;
  late Set<String> _selectedCourses;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _name = TextEditingController(text: s.name);
    _program = TextEditingController(text: s.program);
    _semester = TextEditingController(text: s.semester.toString());
    _newPassword = TextEditingController();
    _selectedCourses = s.courseIds.toSet();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final nameChanged = _name.text.trim() != widget.student.name;
      final newPassword = _newPassword.text.trim();

      if (nameChanged || newPassword.isNotEmpty) {
        await ref.read(backendApiServiceProvider).updateAccount(
              uid: widget.student.uid,
              role: 'student',
              name: nameChanged ? _name.text.trim() : null,
              password: newPassword.isEmpty ? null : newPassword,
            );
      }

      await ref.read(adminRepositoryProvider).updateStudent(
            widget.student.uid,
            program: _program.text.trim(),
            semester: int.tryParse(_semester.text.trim()),
            courses: _selectedCourses.toList(),
          );

      if (!mounted) return;
      if (newPassword.isNotEmpty) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Password reset'),
            content: SelectableText(
              'New password for ${widget.student.email}: $newPassword\n\n'
              'Share this with the student securely.',
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(courseOptionsProvider);

    return AlertDialog(
      title: Text('Edit ${widget.student.registrationNumber}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _program, decoration: const InputDecoration(labelText: 'Program'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _semester,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: Text('Courses', style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 6),
              coursesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load courses.'),
                data: (courses) => Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: courses
                      .map((c) => FilterChip(
                            label: Text(c.name),
                            selected: _selectedCourses.contains(c.id),
                            onSelected: (sel) => setState(() {
                              sel ? _selectedCourses.add(c.id) : _selectedCourses.remove(c.id);
                            }),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _newPassword,
                decoration: const InputDecoration(
                  labelText: 'New password (optional)',
                  helperText: 'Leave blank to keep the current password.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
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

  @override
  void dispose() {
    _name.dispose();
    _program.dispose();
    _semester.dispose();
    _newPassword.dispose();
    super.dispose();
  }
}