import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/dashboard_models.dart';
import '../../models/student_model.dart';
import '../../providers/admin_providers.dart';
import '../../providers/admin_student_providers.dart';

/// Read-only overview of one student for the Admin: profile, courses,
/// library loans and bus stop, all on one page.
class AdminStudentOverviewScreen extends ConsumerWidget {
  final StudentModel student;
  const AdminStudentOverviewScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(studentAccountActiveProvider(student.uid)).valueOrNull;
    final loansAsync = ref.watch(adminStudentLoansProvider(student.uid));
    final bus = ref.watch(adminStudentBusProvider(student.uid)).valueOrNull;
    final courses = ref.watch(courseOptionsProvider).valueOrNull ?? const [];
    final dateFmt = DateFormat('d MMM yyyy');

    final loans = loansAsync.valueOrNull ?? const <LibraryIssueModel>[];
    final current = loans.where((l) => l.status != LibraryIssueStatus.returned).toList();
    final returned = loans.length - current.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Student overview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accentLightBlue,
                  child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primaryBlueDark, fontWeight: FontWeight.w800, fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navyText)),
                      Text(student.registrationNumber, style: const TextStyle(color: AppColors.bodyText)),
                      Text('${student.program} · Semester ${student.semester}', style: const TextStyle(color: AppColors.bodyText)),
                      Text(student.email, style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                label: active == null ? 'Account: ...' : (active ? 'Account active' : 'Account deactivated'),
                color: active == false ? AppColors.error : AppColors.success,
                icon: active == false ? Icons.block : Icons.check_circle_outline,
              ),
            ],
          ),
          _Heading('Courses'),
          if (student.courseIds.isEmpty)
            const _Empty('Not registered in any course.')
          else
            _Card(
              child: Column(
                children: [
                  for (final id in student.courseIds)
                    _CourseRow(
                      courseName: courses.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? id,
                    ),
                ],
              ),
            ),
          _Heading('Library'),
          if (loansAsync.hasError)
            const _Empty('Could not load library records.')
          else if (loans.isEmpty)
            const _Empty('No books issued so far.')
          else
            _Card(
              child: Column(
                children: [
                  if (current.isEmpty) const Padding(padding: EdgeInsets.all(6), child: Text('No books currently issued.')),
                  for (final l in current)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        l.status == LibraryIssueStatus.overdue ? Icons.watch_later_outlined : Icons.menu_book_outlined,
                        color: l.status == LibraryIssueStatus.overdue ? AppColors.error : AppColors.primaryBlue,
                      ),
                      title: Text(l.bookTitle),
                      subtitle: Text('Due ${dateFmt.format(l.expiryDate)}${l.status == LibraryIssueStatus.overdue ? ' - OVERDUE' : ''}',
                          style: TextStyle(color: l.status == LibraryIssueStatus.overdue ? AppColors.error : AppColors.bodyText)),
                    ),
                  if (returned > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('$returned book${returned == 1 ? '' : 's'} returned earlier',
                            style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
                      ),
                    ),
                ],
              ),
            ),
          _Heading('Bus'),
          _Card(
            child: Row(
              children: [
                const Icon(Icons.directions_bus_filled_outlined, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bus == null ? 'Not assigned to a bus.' : '${bus.busId} - stop: ${bus.stopName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final String courseName;
  const _CourseRow({required this.courseName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(child: Text(courseName, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navyText)),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => _Card(child: Text(text, style: const TextStyle(color: AppColors.bodyText)));
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Chip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}
