import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/student_csv.dart';
import '../../core/utils/student_import.dart';
import '../../models/course_model.dart';
import '../../models/student_model.dart';
import '../../providers/admin_providers.dart';
import '../../services/backend_api_service.dart';

enum _Step { choose, review, importing, done }

/// Admin > Students > Import: create many students from one CSV file.
///
/// The file is checked completely first and every problem is shown by row;
/// nothing is created until the Admin confirms. Accounts are created through
/// the same server call as "Add Student", so each gets a random temporary
/// password and must choose their own at first sign-in.
class AdminStudentsImportScreen extends ConsumerStatefulWidget {
  const AdminStudentsImportScreen({super.key});

  @override
  ConsumerState<AdminStudentsImportScreen> createState() =>
      _AdminStudentsImportScreenState();
}

class _AdminStudentsImportScreenState
    extends ConsumerState<AdminStudentsImportScreen> {
  final _text = TextEditingController();
  _Step _step = _Step.choose;
  String? _error;
  String? _fileName;
  StudentCsvResult? _result;
  List<ImportOutcome> _outcomes = const [];
  int _done = 0;
  int _total = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
      );
      if (file == null) return;
      final path = file.path;
      if (path == null) {
        setState(
          () => _error =
              'Could not read that file. Try pasting its contents instead.',
        );
        return;
      }
      final content = await File(path).readAsString();
      setState(() {
        _text.text = content;
        _fileName = file.name;
        _error = null;
      });
    } catch (e) {
      if (mounted)
        setState(
          () => _error =
              'Could not open the file. Try pasting its contents instead.',
        );
    }
  }

  Future<void> _check() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Choose a CSV file or paste its contents first.');
      return;
    }
    // wait for the list of existing students, so duplicates are caught here and
    // not only when the server refuses them one by one
    List<StudentModel> students;
    try {
      students = await ref.read(allStudentsProvider.future);
    } catch (_) {
      students = const [];
    }
    List<CourseModel> courses;
    try {
      courses = await ref.read(courseOptionsProvider.future);
    } catch (_) {
      courses = const [];
    }
    final result = parseStudentCsv(
      _text.text,
      knownCourseIds: courses.map((c) => c.id).toSet(),
      existingRegistrationNumbers: students
          .map((s) => s.registrationNumber)
          .toSet(),
      existingEmails: students.map((s) => s.email).toSet(),
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _error = result.fileErrors.isEmpty ? null : result.fileErrors.join('\n');
      if (result.fileErrors.isEmpty) _step = _Step.review;
    });
  }

  Future<void> _import() async {
    final rows = _result!.valid;
    setState(() {
      _step = _Step.importing;
      _done = 0;
      _total = rows.length;
    });

    final api = ref.read(backendApiServiceProvider);
    final outcomes = await importStudents(
      rows,
      create: (r) => api.createAccount(
        email: r.email,
        name: r.name,
        role: 'student',
        studentFields: {
          'registrationNumber': r.registrationNumber,
          'program': r.program,
          'semester': r.semester,
          'courses': r.courses,
        },
      ),
      // a refusal of one row is a BackendApiException; anything else means the server is unreachable
      isFatal: (e) => e is! BackendApiException,
      describe: (e) => e is BackendApiException
          ? e.message
          : 'Could not reach the SecureCampus server. Check it is running and the phone can reach it.',
      onProgress: (d, t) {
        if (mounted) setState(() => _done = d);
      },
    );
    if (!mounted) return;
    setState(() {
      _outcomes = outcomes;
      _step = _Step.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(allStudentsProvider); // keep the existing-students list loaded
    ref.watch(courseOptionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import students'),
        automaticallyImplyLeading: _step != _Step.importing,
      ),
      body: SafeArea(
        child: switch (_step) {
          _Step.choose => _buildChoose(),
          _Step.review => _buildReview(),
          _Step.importing => _buildImporting(),
          _Step.done => _buildDone(),
        },
      ),
    );
  }

  // ------------------------------------------------------------ step 1
  Widget _buildChoose() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Add many students at once from a CSV file.',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'One row per student. The first row must name the columns:\n'
                'name, email, registration_number, program, semester, courses\n'
                'Courses are IDs separated by ; (for example SE;AI). Program and semester may be left empty.',
                style: TextStyle(color: AppColors.bodyText, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose CSV file'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: studentCsvTemplate),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Template copied. Paste it into a spreadsheet.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy template'),
                  ),
                ],
              ),
              if (_fileName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'File: $_fileName',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _text,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Or paste the CSV here',
                  alignLabelWithHint: true,
                  hintText:
                      'name,email,registration_number,program,semester,courses',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _check,
              child: const Text('Check file'),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 2
  Widget _buildReview() {
    final result = _result!;
    final valid = result.valid;
    final invalid = result.invalid;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Banner(
                color: invalid.isEmpty ? AppColors.success : AppColors.warning,
                icon: invalid.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                text: invalid.isEmpty
                    ? 'All ${valid.length} row${valid.length == 1 ? '' : 's'} look good.'
                    : '${valid.length} ready to import, ${invalid.length} with problems (these will be skipped).',
              ),
              if (invalid.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Rows with problems',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final r in invalid)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Line ${r.line}${r.name.isEmpty ? '' : ' - ${r.name}'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          for (final e in r.errors)
                            Text(
                              '• $e',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (valid.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Ready to import (${valid.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final r in valid)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: AppColors.success,
                    ),
                    title: Text(r.name),
                    subtitle: Text(
                      '${r.registrationNumber} · ${r.program}, Sem ${r.semester}'
                      '${r.courses.isEmpty ? '' : ' · ${r.courses.join(', ')}'}',
                    ),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = _Step.choose),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: valid.isEmpty ? null : _import,
                  child: Text(
                    'Import ${valid.length} student${valid.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 3
  Widget _buildImporting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Creating accounts...',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            const SizedBox(height: 10),
            Text(
              '$_done of $_total',
              style: const TextStyle(color: AppColors.bodyText),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please keep this screen open.',
              style: TextStyle(color: AppColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ step 4
  Widget _buildDone() {
    final created = _outcomes.where((o) => o.created).toList();
    final failed = _outcomes.where((o) => !o.created).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Banner(
                color: failed.isEmpty ? AppColors.success : AppColors.warning,
                icon: failed.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                text:
                    '${created.length} account${created.length == 1 ? '' : 's'} created'
                    '${failed.isEmpty ? '.' : ', ${failed.length} not created.'}',
              ),
              if (created.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Each student has a temporary password, shown only now. Copy the list and give each student '
                    'their own password privately. They must choose a new one the first time they sign in.',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: createdAccountsCsv(_outcomes)),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Accounts and temporary passwords copied.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy accounts and passwords'),
                ),
              ],
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Not created',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final o in failed)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        o.attempted
                            ? Icons.error_outline
                            : Icons.pause_circle_outline,
                        color: o.attempted
                            ? AppColors.error
                            : AppColors.bodyText,
                      ),
                      title: Text(
                        '${o.row.name} (${o.row.registrationNumber})',
                      ),
                      subtitle: Text(o.error ?? ''),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
