import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../models/admin_models.dart';
import '../../providers/librarian_providers.dart';

class LibrarianIssuedBooksScreen extends ConsumerWidget {
  const LibrarianIssuedBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(activeIssuesProvider);
    final dateFmt = DateFormat('dd MMM yyyy');

    return Container(
      color: AppColors.background,
      child: issuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load issued books.\n$err')),
        data: (issues) {
          if (issues.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No books currently issued.', style: TextStyle(color: AppColors.bodyText)),
              ),
            );
          }
          final overdue = issues.where((i) => i.isOverdue).length;

          return Column(
            children: [
              if (overdue > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '$overdue book${overdue == 1 ? '' : 's'} overdue',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: issues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _IssueCard(issue: issues[i], dateFmt: dateFmt),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IssueCard extends ConsumerStatefulWidget {
  final LibrarianIssueRow issue;
  final DateFormat dateFmt;
  const _IssueCard({required this.issue, required this.dateFmt});

  @override
  ConsumerState<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends ConsumerState<_IssueCard> {
  bool _returning = false;

  Future<void> _handleReturn() async {
    setState(() => _returning = true);
    try {
      await ref.read(librarianRepositoryProvider).returnBook(widget.issue);
    } finally {
      if (mounted) setState(() => _returning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final overdue = issue.isOverdue;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: overdue ? Border.all(color: AppColors.error.withValues(alpha: 0.35)) : null,
          boxShadow: [
            BoxShadow(
              color: (overdue ? AppColors.error : AppColors.navyText).withValues(alpha: overdue ? 0.10 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (overdue ? AppColors.error : AppColors.primaryBlue).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                overdue ? Icons.watch_later_outlined : Icons.menu_book_outlined,
                color: overdue ? AppColors.error : AppColors.primaryBlueDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text('${issue.studentName} · ${issue.registrationNumber}',
                      style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 13, color: AppColors.bodyText.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('Issued ${widget.dateFmt.format(issue.issueDate)}',
                          style: TextStyle(color: AppColors.bodyText.withValues(alpha: 0.9), fontSize: 11.5)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.event_busy_outlined, size: 13, color: overdue ? AppColors.error : AppColors.bodyText.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${widget.dateFmt.format(issue.expiryDate)}',
                        style: TextStyle(
                          color: overdue ? AppColors.error : AppColors.bodyText.withValues(alpha: 0.9),
                          fontWeight: overdue ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (overdue)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                    child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                  ),
                PressableScale(
                  onTap: _returning ? null : _handleReturn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: _returning
                        ? const SizedBox(
                            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}