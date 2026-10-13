import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_hero_header.dart';
import '../../../models/dashboard_models.dart';
import '../../../providers/issue_report_providers.dart';
import '../../../providers/student_providers.dart';

class LibrarySection extends ConsumerWidget {
  const LibrarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(libraryIssuesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeroHeader(
          icon: Icons.menu_book_outlined,
          title: 'Library',
          subtitle: 'Books currently issued to you, and their due dates.',
        ),
        const SizedBox(height: 20),
        issuesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (_, __) => const Text('Could not load library records.', style: TextStyle(color: AppColors.error)),
          data: (issues) {
            final active = issues.where((i) => i.status != LibraryIssueStatus.returned).toList();
            if (active.isEmpty) {
              return const Text('No books currently issued.', style: TextStyle(color: AppColors.bodyText));
            }
            return Column(children: active.map((issue) => _IssueRow(issue: issue)).toList());
          },
        ),
      ],
    );
  }
}

class _IssueRow extends ConsumerWidget {
  final LibraryIssueModel issue;
  const _IssueRow({required this.issue});

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final student = ref.read(studentProfileProvider).value;
    if (student == null) return;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report unauthorized issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tell the librarian and security that you did not borrow "${issue.bookTitle}".'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send report')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(issueReportRepositoryProvider).submit(issue: issue, student: student, note: noteController.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report sent to the librarian and security.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = issue.status == LibraryIssueStatus.overdue;
    final dateFmt = DateFormat('dd MMM yyyy');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isOverdue ? AppColors.error : AppColors.primaryBlue).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isOverdue ? AppColors.error.withValues(alpha: 0.35) : AppColors.divider),
          boxShadow: [
            BoxShadow(color: AppColors.navyText.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isOverdue ? AppColors.error : AppColors.primaryBlue).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOverdue ? Icons.watch_later_outlined : Icons.menu_book_outlined,
                color: isOverdue ? AppColors.error : AppColors.primaryBlueDark,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    'Issued ${dateFmt.format(issue.issueDate)}  ·  Due ${dateFmt.format(issue.expiryDate)}',
                    style: TextStyle(color: AppColors.bodyText, fontSize: 12),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(height: 4),
                    const Text('Fine: Rs. 100 (informational — no online payment)',
                        style: TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 2),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                    onPressed: () => _report(context, ref),
                    icon: const Icon(Icons.report_gmailerrorred_outlined, size: 16),
                    label: const Text('I did not borrow this', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isOverdue ? AppColors.error : AppColors.success,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                isOverdue ? 'OVERDUE' : 'ISSUED',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}