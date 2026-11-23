import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/utils/catalog_logic.dart';
import '../../core/utils/student_search.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';
import '../librarian/librarian_reports_screen.dart';
import '../library/book_lock_ui.dart';
import 'book_qr_dialog.dart';

enum _AvailabilityFilter { all, available, issued, locked }

/// Admin > Library, one page per sub-module: the book Catalog, or Reports
/// (library summary plus the students' "I did not borrow this book" reports,
/// the same Reports view the librarian sees; the admin can also mark a report
/// resolved). The header bar's Catalog / Reports chips switch between them, so
/// this page has no tab bar of its own.
class AdminLibraryScreen extends ConsumerWidget {
  /// 0 = Catalog, 1 = Reports. The sidebar's Library > Reports opens 1.
  final int initialTab;
  const AdminLibraryScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return initialTab == 1 ? const LibrarianReportsScreen() : const _AdminCatalogView();
  }
}

class _AdminCatalogView extends ConsumerStatefulWidget {
  const _AdminCatalogView();

  @override
  ConsumerState<_AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends ConsumerState<_AdminCatalogView> {
  final _searchController = TextEditingController();
  String _query = '';
  _AvailabilityFilter _filter = _AvailabilityFilter.all;

  List<BookModel> _apply(List<BookModel> books) {
    var result = books;
    if (_filter == _AvailabilityFilter.available) {
      result = result
          .where((b) => bookState(b) == BookState.available)
          .toList();
    } else if (_filter == _AvailabilityFilter.issued) {
      result = result.where((b) => bookState(b) == BookState.issued).toList();
    } else if (_filter == _AvailabilityFilter.locked) {
      result = result.where((b) => bookState(b) == BookState.locked).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where(
            (b) =>
                b.title.toLowerCase().contains(q) ||
                b.id.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _AddBookDialog(existingIds: (booksAsync.valueOrNull ?? const []).map((b) => b.id).toList()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by title, ID, or author',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == _AvailabilityFilter.all,
                  onSelected: (_) =>
                      setState(() => _filter = _AvailabilityFilter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Available'),
                  selected: _filter == _AvailabilityFilter.available,
                  onSelected: (_) =>
                      setState(() => _filter = _AvailabilityFilter.available),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Issued'),
                  selected: _filter == _AvailabilityFilter.issued,
                  onSelected: (_) =>
                      setState(() => _filter = _AvailabilityFilter.issued),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Locked'),
                  selected: _filter == _AvailabilityFilter.locked,
                  onSelected: (_) =>
                      setState(() => _filter = _AvailabilityFilter.locked),
                ),
              ],
            ),
          ),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Could not load books.\n$err')),
              data: (allBooks) {
                if (allBooks.isEmpty)
                  return const Center(
                    child: Text('No books in the catalog yet.'),
                  );
                final books = _apply(allBooks);
                if (books.isEmpty)
                  return const Center(
                    child: Text('No books match your search/filter.'),
                  );
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final b = books[i];
                    final isLocked = bookState(b) == BookState.locked;
                    return Card(
                      child: ListTile(
                        // Every book shows its own QR code (the book ID); tap to enlarge.
                        leading: Tooltip(
                          message: 'Show QR code',
                          child: InkWell(
                            key: ValueKey('row-qr-${b.id}'),
                            onTap: () => showBookQrDialog(context, id: b.id, title: b.title, author: b.author),
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(2),
                              child: QrImageView(data: b.id, size: 52, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                            ),
                          ),
                        ),
                        title: Text(b.title),
                        subtitle: Text(
                          '${b.id} · ${b.author} · ${b.category}'
                          '${isLocked ? '\nLocked by ${b.lockedByName.isEmpty ? 'unknown' : b.lockedByName}: ${b.lockReason}' : ''}',
                        ),
                        isThreeLine: isLocked,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BookStateBadge(book: b),
                            PopupMenuButton<String>(
                              tooltip: 'Book options',
                              onSelected: (v) {
                                if (v == 'lock')
                                  showLockBookDialog(context, ref, b);
                                if (v == 'unlock')
                                  showUnlockBookDialog(context, ref, b);
                                if (v == 'history')
                                  showLockHistorySheet(context, b);
                                if (v == 'qr')
                                  showBookQrDialog(context, id: b.id, title: b.title, author: b.author);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'qr',
                                  child: Text('Show QR code'),
                                ),
                                if (!isLocked)
                                  const PopupMenuItem(
                                    value: 'lock',
                                    child: Text('Lock book...'),
                                  ),
                                if (isLocked)
                                  const PopupMenuItem(
                                    value: 'unlock',
                                    child: Text('Unlock book...'),
                                  ),
                                const PopupMenuItem(
                                  value: 'history',
                                  child: Text('Lock history'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}

class _AddBookDialog extends ConsumerStatefulWidget {
  final List<String> existingIds;
  const _AddBookDialog({this.existingIds = const []});

  @override
  ConsumerState<_AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends ConsumerState<_AddBookDialog> {
  late final _id = TextEditingController(text: nextBookId(widget.existingIds));
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _category = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_id.text.trim().isEmpty || _title.text.trim().isEmpty) return;
    // Saving under an ID that exists would replace that book, so refuse it.
    final taken = widget.existingIds.any((e) => normalizeRegNo(e) == normalizeRegNo(_id.text));
    if (taken) {
      setState(() => _error = '${_id.text.trim()} is already used by another book. Use a different ID.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final pageContext = Navigator.of(context, rootNavigator: true).context;
    try {
      final id = _id.text.trim();
      final title = _title.text.trim();
      final author = _author.text.trim();
      await ref.read(adminRepositoryProvider).upsertBook(id, title, author, _category.text.trim());
      if (!mounted) return;
      navigator.pop();
      // The new book's QR code comes up straight away.
      if (pageContext.mounted) await showBookQrDialog(pageContext, id: id, title: title, author: author);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Book'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              decoration: const InputDecoration(
                labelText: 'Book ID (e.g. BOOK-006)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _author,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('book-id-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'The ID is filled in for you. Its QR code is made automatically when you press Add.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
