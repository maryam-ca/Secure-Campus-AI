import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../models/admin_models.dart';
import '../../providers/book_lock_providers.dart';
import '../../repositories/book_lock_repository.dart';

/// AVAILABLE / ISSUED / LOCKED pill, shared by the Librarian and Admin catalogs.
class BookStateBadge extends StatelessWidget {
  final BookModel book;
  const BookStateBadge({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (bookState(book)) {
      BookState.available => ('AVAILABLE', AppColors.success, Icons.check_circle),
      BookState.issued => ('ISSUED', AppColors.warning, Icons.person),
      BookState.locked => ('LOCKED', AppColors.locked, Icons.lock),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10.5)),
        ],
      ),
    );
  }
}

String _when(DateTime? t) => t == null ? 'just now' : DateFormat('dd MMM yyyy, hh:mm a').format(t.toLocal());

/// Asks for a reason (free text, required) and locks the book. Only a book
/// that has been received can be locked; an issued one must be returned first.
Future<void> showLockBookDialog(BuildContext context, WidgetRef ref, BookModel book) async {
  if (!book.available) {
    _snack(context, 'This book is currently issued. Receive (return) it first, then lock it.');
    return;
  }
  final reason = await _askReason(
    context,
    title: 'Lock "${book.title}"',
    message: 'Keep this book physically in the safe. It cannot be issued while it is locked.',
    action: 'Lock book',
  );
  if (reason == null || !context.mounted) return;

  final actor = ref.read(lockActorProvider);
  if (actor == null) return _snack(context, 'You are not signed in.');
  try {
    await ref.read(bookLockRepositoryProvider).lockBook(bookId: book.id, reason: reason, actor: actor);
    if (context.mounted) _snack(context, '"${book.title}" is now locked.');
  } on BookLockException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (e) {
    if (context.mounted) _snack(context, _friendly('lock', e));
  }
}

/// Asks for a reason (required) and unlocks the book. The history keeps who
/// locked it, who unlocked it, and why.
Future<void> showUnlockBookDialog(BuildContext context, WidgetRef ref, BookModel book) async {
  final reason = await _askReason(
    context,
    title: 'Unlock "${book.title}"',
    message: 'Locked by ${book.lockedByName.isEmpty ? 'unknown' : book.lockedByName} on ${_when(book.lockedAt)}.\n'
        'Reason: ${book.lockReason.isEmpty ? '-' : book.lockReason}',
    action: 'Unlock book',
    label: 'Why is it being unlocked?',
  );
  if (reason == null || !context.mounted) return;

  final actor = ref.read(lockActorProvider);
  if (actor == null) return _snack(context, 'You are not signed in.');
  try {
    await ref.read(bookLockRepositoryProvider).unlockBook(bookId: book.id, reason: reason, actor: actor);
    if (context.mounted) _snack(context, '"${book.title}" is unlocked and can be issued.');
  } on BookLockException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (e) {
    if (context.mounted) _snack(context, _friendly('unlock', e));
  }
}

/// Bottom sheet listing every lock and unlock for a book, newest first.
Future<void> showLockHistorySheet(BuildContext context, BookModel book) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LockHistorySheet(book: book),
  );
}

/// Plain-language message for a failed lock/unlock. A permission error means the
/// Firestore rules that allow lock history are not published in the project yet.
String _friendly(String action, Object e) {
  if (e.toString().contains('permission-denied')) {
    return 'Could not $action the book: Firebase refused the change (permission denied). '
        'The database rules for locking have not been published yet. Ask the administrator to publish them.';
  }
  return 'Could not $action the book: $e';
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> _askReason(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String label = 'Reason (required)',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, message: message, action: action, label: label),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String message;
  final String action;
  final String label;
  const _ReasonDialog({required this.title, required this.message, required this.action, required this.label});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'A reason is required.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 200,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: widget.label, errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

class _LockHistorySheet extends ConsumerWidget {
  final BookModel book;
  const _LockHistorySheet({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(bookLockHistoryProvider(book.id));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Lock history - ${book.title}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            Flexible(
              child: historyAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load history.\n$e')),
                data: (events) {
                  if (events.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Text('This book has never been locked.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = events[i];
                      final color = e.isLock ? AppColors.locked : AppColors.success;
                      return ListTile(
                        leading: Icon(e.isLock ? Icons.lock : Icons.lock_open, color: color),
                        title: Text('${e.isLock ? 'Locked' : 'Unlocked'} by ${e.byName.isEmpty ? e.byUid : e.byName}'
                            '${e.byRole.isEmpty ? '' : ' (${e.byRole})'}'),
                        subtitle: Text('${_when(e.at)}\nReason: ${e.reason}'),
                        isThreeLine: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
