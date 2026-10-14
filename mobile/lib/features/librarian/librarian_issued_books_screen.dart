import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/issue_search.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../models/admin_models.dart';
import '../../providers/librarian_providers.dart';
import 'return_verify_screen.dart';

class LibrarianIssuedBooksScreen extends ConsumerStatefulWidget {
  const LibrarianIssuedBooksScreen({super.key});

  @override
  ConsumerState<LibrarianIssuedBooksScreen> createState() => _LibrarianIssuedBooksScreenState();
}

class _LibrarianIssuedBooksScreenState extends ConsumerState<LibrarianIssuedBooksScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _overdueOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(activeIssuesProvider);
    final dateFmt = DateFormat('dd MMM yyyy');

    return Container(
      color: AppColors.background,
      child: issuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load issued books.\n$err')),
        data: (all) {
          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No books currently issued.', style: TextStyle(color: AppColors.bodyText)),
              ),
            );
          }
          final overdueCount = all.where((i) => i.isOverdue).length;
          final searched = searchIssues(all, _query);
          final issues = _overdueOnly ? searched.where((i) => i.isOverdue).toList() : searched;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search book title or ID, student name or ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${all.length})'),
                      selected: !_overdueOnly,
                      onSelected: (_) => setState(() => _overdueOnly = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Overdue ($overdueCount)'),
                      selected: _overdueOnly,
                      selectedColor: AppColors.error.withValues(alpha: 0.18),
                      onSelected: (_) => setState(() => _overdueOnly = true),
                    ),
                    const Spacer(),
                    Text('${issues.length} shown', style: const TextStyle(color: AppColors.bodyText, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: issues.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No issued books match your search.',
                              style: TextStyle(color: AppColors.bodyText)),
                        ),
                      )
                    : ListView.separated(
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

  /// The book in hand must be confirmed first (scan its QR, or type its ID).
  /// Only then is the loan returned.
  Future<void> _handleReturn() async {
    final method = await Navigator.of(context).push<ReturnMethod>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReturnVerifyScreen(issue: widget.issue),
      ),
    );
    if (method == null || !mounted) return;

    setState(() => _returning = true);
    try {
      await ref.read(librarianRepositoryProvider).returnBook(widget.issue, method: method);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Returned "${widget.issue.bookTitle}" from ${widget.issue.studentName}'
              '${method == ReturnMethod.manual ? ' (ID entered manually)' : ''}.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not return the book: $e')));
      }
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