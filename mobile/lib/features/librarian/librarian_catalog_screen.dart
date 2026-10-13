import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/librarian_providers.dart';

enum _AvailabilityFilter { all, available, issued }

class LibrarianCatalogScreen extends ConsumerStatefulWidget {
  const LibrarianCatalogScreen({super.key});

  @override
  ConsumerState<LibrarianCatalogScreen> createState() => _LibrarianCatalogScreenState();
}

class _LibrarianCatalogScreenState extends ConsumerState<LibrarianCatalogScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _AvailabilityFilter _filter = _AvailabilityFilter.all;

  List<BookModel> _apply(List<BookModel> books) {
    var result = books;
    if (_filter == _AvailabilityFilter.available) {
      result = result.where((b) => b.available).toList();
    } else if (_filter == _AvailabilityFilter.issued) {
      result = result.where((b) => !b.available).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where((b) => b.title.toLowerCase().contains(q) || b.id.toLowerCase().contains(q) || b.author.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  Widget _filterChip(String label, _AvailabilityFilter value, IconData icon) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : AppColors.accentLightBlue.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : AppColors.primaryBlueDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primaryBlueDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(librarianBooksProvider);

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by title, ID, or author',
                prefixIcon: const Icon(Icons.search, size: 20),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                _filterChip('All', _AvailabilityFilter.all, Icons.grid_view_rounded),
                const SizedBox(width: 8),
                _filterChip('Available', _AvailabilityFilter.available, Icons.check_circle_outline),
                const SizedBox(width: 8),
                _filterChip('Issued', _AvailabilityFilter.issued, Icons.person_outline),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Could not load catalog.\n$err')),
              data: (allBooks) {
                if (allBooks.isEmpty) {
                  return const Center(child: Text('No books in the catalog.', style: TextStyle(color: AppColors.bodyText)));
                }
                final books = _apply(allBooks);
                if (books.isEmpty) {
                  return const Center(child: Text('No books match your search/filter.', style: TextStyle(color: AppColors.bodyText)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _BookCard(book: books[i]),
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
}

class _BookCard extends StatelessWidget {
  final BookModel book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.navyText.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: AppColors.accentLightBlue, shape: BoxShape.circle),
              child: const Icon(Icons.menu_book_outlined, color: AppColors.primaryBlueDark, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text('${book.id} · ${book.author}', style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(book.category, style: TextStyle(color: AppColors.bodyText.withValues(alpha: 0.75), fontSize: 11.5)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (book.available ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    book.available ? Icons.check_circle : Icons.person,
                    size: 13,
                    color: book.available ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    book.available ? 'AVAILABLE' : 'ISSUED',
                    style: TextStyle(
                      color: book.available ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}