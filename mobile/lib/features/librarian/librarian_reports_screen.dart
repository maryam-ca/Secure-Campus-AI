import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../models/admin_models.dart';
import '../../providers/issue_report_providers.dart';
import '../../providers/librarian_providers.dart';
import '../common/issue_reports_screen.dart';

/// Reports tab: a short library summary on top, then the students'
/// "I did not borrow this book" reports below.
class LibrarianReportsScreen extends ConsumerWidget {
  const LibrarianReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(librarianBooksProvider).valueOrNull ?? const <BookModel>[];
    final loans = ref.watch(activeIssuesProvider).valueOrNull ?? const <LibrarianIssueRow>[];
    final reports = ref.watch(issueReportsProvider).valueOrNull ?? const [];

    final counts = catalogCounts(books, loans);
    final newReports = reports.where((r) => r.isOpen).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              _Tile(label: 'Issued now', value: loans.length, color: AppColors.warning, icon: Icons.assignment_outlined),
              _Tile(label: 'Overdue', value: counts.overdue, color: AppColors.error, icon: Icons.watch_later_outlined),
              _Tile(label: 'Locked', value: counts.locked, color: AppColors.error, icon: Icons.lock_outline),
              _Tile(
                  label: 'New reports',
                  value: newReports,
                  color: AppColors.primaryBlue,
                  icon: Icons.report_gmailerrorred_outlined),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Student reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        const Expanded(child: IssueReportsScreen()),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _Tile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.bodyText, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
