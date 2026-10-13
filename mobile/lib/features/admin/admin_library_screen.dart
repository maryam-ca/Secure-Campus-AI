import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

enum _AvailabilityFilter { all, available, issued }

class AdminLibraryScreen extends ConsumerStatefulWidget {
  const AdminLibraryScreen({super.key});

  @override
  ConsumerState<AdminLibraryScreen> createState() => _AdminLibraryScreenState();
}

class _AdminLibraryScreenState extends ConsumerState<AdminLibraryScreen> {
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

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => const _AddBookDialog()),
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
              decoration: const InputDecoration(hintText: 'Search by title, ID, or author', prefixIcon: Icon(Icons.search, size: 20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(label: const Text('All'), selected: _filter == _AvailabilityFilter.all, onSelected: (_) => setState(() => _filter = _AvailabilityFilter.all)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Available'), selected: _filter == _AvailabilityFilter.available, onSelected: (_) => setState(() => _filter = _AvailabilityFilter.available)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Issued'), selected: _filter == _AvailabilityFilter.issued, onSelected: (_) => setState(() => _filter = _AvailabilityFilter.issued)),
              ],
            ),
          ),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Could not load books.\n$err')),
              data: (allBooks) {
                if (allBooks.isEmpty) return const Center(child: Text('No books in the catalog yet.'));
                final books = _apply(allBooks);
                if (books.isEmpty) return const Center(child: Text('No books match your search/filter.'));
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final b = books[i];
                    return Card(
                      child: ListTile(
                        title: Text(b.title),
                        subtitle: Text('${b.id} · ${b.author} · ${b.category}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (b.available ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b.available ? 'AVAILABLE' : 'ISSUED',
                            style: TextStyle(
                              color: b.available ? AppColors.success : AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
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
  const _AddBookDialog();

  @override
  ConsumerState<_AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends ConsumerState<_AddBookDialog> {
  final _id = TextEditingController();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _category = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    if (_id.text.trim().isEmpty || _title.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).upsertBook(
            _id.text.trim(),
            _title.text.trim(),
            _author.text.trim(),
            _category.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
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
            TextField(controller: _id, decoration: const InputDecoration(labelText: 'Book ID (e.g. BOOK-006)')),
            const SizedBox(height: 10),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: _author, decoration: const InputDecoration(labelText: 'Author')),
            const SizedBox(height: 10),
            TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Generate its QR code with scripts/generate_qr_codes.py after adding a new book ID here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add'),
        ),
      ],
    );
  }
}
