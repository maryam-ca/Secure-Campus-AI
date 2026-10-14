import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../models/admin_models.dart';
import '../../providers/librarian_providers.dart';
import '../library/book_lock_ui.dart';
import 'issued_loan_card.dart';

/// The librarian's catalog. Sub-tabs, each with its count underneath:
/// All, Available, Issued, Overdue, Locked. Issued and Overdue show the
/// loans (student, due date, Return); the others show books.
class LibrarianCatalogScreen extends ConsumerStatefulWidget {
  const LibrarianCatalogScreen({super.key});

  @override
  ConsumerState<LibrarianCatalogScreen> createState() => _LibrarianCatalogScreenState();
}

class _LibrarianCatalogScreenState extends ConsumerState<LibrarianCatalogScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  CatalogFilter _filter = CatalogFilter.all;

  static const _labels = {
    CatalogFilter.all: 'All',
    CatalogFilter.available: 'Available',
    CatalogFilter.issued: 'Issued',
    CatalogFilter.overdue: 'Overdue',
    CatalogFilter.locked: 'Locked',
  };

  bool get _showsLoans => _filter == CatalogFilter.issued || _filter == CatalogFilter.overdue;

  Color _colorFor(CatalogFilter f) {
    switch (f) {
      case CatalogFilter.overdue:
      case CatalogFilter.locked:
        return AppColors.error;
      case CatalogFilter.issued:
        return AppColors.warning;
      case CatalogFilter.available:
        return AppColors.success;
      case CatalogFilter.all:
        return AppColors.primaryBlue;
    }
  }

  Widget _subTab(CatalogFilter f, int count) {
    final selected = _filter == f;
    final color = _colorFor(f);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        key: ValueKey('catalog-tab-${f.name}'),
        onTap: () => setState(() => _filter = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _labels[f]!,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                key: ValueKey('catalog-count-${f.name}'),
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(librarianBooksProvider);
    final loans = ref.watch(activeIssuesProvider).value ?? const <LibrarianIssueRow>[];
    final dateFmt = DateFormat('dd MMM yyyy');

    return Container(
      color: AppColors.background,
      child: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load catalog.\n$err')),
        data: (allBooks) {
          final counts = catalogCounts(allBooks, loans);

          Widget body;
          if (allBooks.isEmpty) {
            body = const Center(child: Text('No books in the catalog.', style: TextStyle(color: AppColors.bodyText)));
          } else if (_showsLoans) {
            final shown = loansForFilter(loans, _filter, _query);
            body = shown.isEmpty
                ? Center(
                    child: Text(
                      _filter == CatalogFilter.overdue ? 'No overdue books.' : 'No issued books match.',
                      style: const TextStyle(color: AppColors.bodyText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => IssuedLoanCard(issue: shown[i], dateFmt: dateFmt),
                  );
          } else {
            final shown = booksForFilter(allBooks, _filter, _query);
            body = shown.isEmpty
                ? Center(
                    child: Text(
                      _filter == CatalogFilter.locked ? 'No locked books.' : 'No books match your search/filter.',
                      style: const TextStyle(color: AppColors.bodyText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _BookCard(book: shown[i]),
                  );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: _showsLoans
                        ? 'Search book title or ID, student name or ID'
                        : 'Search by title, ID, or author',
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
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 6, 4),
                child: Row(
                  children: [for (final f in CatalogFilter.values) _subTab(f, counts.forFilter(f))],
                ),
              ),
              if (_filter == CatalogFilter.overdue || _filter == CatalogFilter.issued)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _filter == CatalogFilter.overdue
                          ? 'Overdue books are also counted under Issued.'
                          : 'Return a book by scanning it, or typing its ID.',
                      style: const TextStyle(color: AppColors.bodyText, fontSize: 11.5),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _BookCard extends ConsumerWidget {
  final BookModel book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = bookState(book);
    final locked = state == BookState.locked;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) =>
          Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: locked ? Border.all(color: AppColors.error.withValues(alpha: 0.35)) : null,
          boxShadow: [
            BoxShadow(color: AppColors.navyText.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: locked ? AppColors.error.withValues(alpha: 0.12) : AppColors.accentLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                locked ? Icons.lock_outline : Icons.menu_book_outlined,
                color: locked ? AppColors.error : AppColors.primaryBlueDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text('${book.id} · ${book.author}',
                      style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(book.category,
                      style: TextStyle(color: AppColors.bodyText.withValues(alpha: 0.75), fontSize: 11.5)),
                  if (locked) ...[
                    const SizedBox(height: 6),
                    Text('Reason: ${book.lockReason.isEmpty ? '-' : book.lockReason}',
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      'Locked by ${book.lockedByName.isEmpty ? 'unknown' : book.lockedByName}'
                      '${book.lockedAt == null ? '' : ' · ${DateFormat('dd MMM yyyy').format(book.lockedAt!.toLocal())}'}',
                      style: const TextStyle(color: AppColors.bodyText, fontSize: 11.5),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                      onPressed: () => showUnlockBookDialog(context, ref, book),
                      icon: const Icon(Icons.lock_open, size: 16),
                      label: const Text('Unlock', style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BookStateBadge(book: book),
                PopupMenuButton<String>(
                  tooltip: 'Book options',
                  onSelected: (v) {
                    if (v == 'lock') showLockBookDialog(context, ref, book);
                    if (v == 'unlock') showUnlockBookDialog(context, ref, book);
                    if (v == 'history') showLockHistorySheet(context, book);
                  },
                  itemBuilder: (_) => [
                    if (!locked) const PopupMenuItem(value: 'lock', child: Text('Lock book...')),
                    if (locked) const PopupMenuItem(value: 'unlock', child: Text('Unlock book...')),
                    const PopupMenuItem(value: 'history', child: Text('Lock history')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
