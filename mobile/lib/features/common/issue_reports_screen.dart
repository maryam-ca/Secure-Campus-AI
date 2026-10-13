import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/issue_report_model.dart';
import '../../providers/issue_report_providers.dart';

/// Student reports of books they say they never borrowed. Shown to the
/// Librarian and to Security (proposal 4.2), who can mark each resolved.
class IssueReportsScreen extends ConsumerWidget {
  const IssueReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(issueReportsProvider);
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load reports.\n$err')),
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(child: Text('No unauthorized-issue reports.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ReportCard(report: reports[i], dateFmt: dateFmt),
        );
      },
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final IssueReportModel report;
  final DateFormat dateFmt;
  const _ReportCard({required this.report, required this.dateFmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = report.isOpen;
    final color = open ? AppColors.error : AppColors.success;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(open ? Icons.report_gmailerrorred_outlined : Icons.check_circle_outline, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                  child: Text(open ? 'NEW' : 'RESOLVED',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${report.studentName} (${report.registrationNumber}) says they did not borrow this book.'),
            if (report.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('"${report.note}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Text(report.createdAt == null ? '' : dateFmt.format(report.createdAt!.toLocal()),
                    style: TextStyle(color: AppColors.bodyText, fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: () => ref
                      .read(issueReportRepositoryProvider)
                      .setResolved(report.id, resolved: open),
                  child: Text(open ? 'Mark resolved' : 'Reopen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
