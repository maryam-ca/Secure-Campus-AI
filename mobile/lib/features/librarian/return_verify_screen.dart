import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/catalog_logic.dart';
import '../../core/utils/issue_search.dart';
import '../../models/admin_models.dart';
import '../../providers/librarian_providers.dart';

/// Confirms that the book in the librarian's hand is the one being returned.
///
/// Pops with [ReturnMethod.scan] when the book's QR matches the loan, or
/// [ReturnMethod.manual] when the librarian typed the matching book ID
/// (QR torn or unreadable) and confirmed. Pops with null if cancelled. A
/// wrong book never returns the loan: the screen explains which book was
/// scanned instead.
class ReturnVerifyScreen extends ConsumerStatefulWidget {
  final LibrarianIssueRow issue;
  const ReturnVerifyScreen({super.key, required this.issue});

  @override
  ConsumerState<ReturnVerifyScreen> createState() => _ReturnVerifyScreenState();
}

class _ReturnVerifyScreenState extends ConsumerState<ReturnVerifyScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_checking) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.trim().isEmpty) return;
    _checking = true;

    if (bookCodeMatches(code, widget.issue.bookId)) {
      if (mounted) Navigator.of(context).pop(ReturnMethod.scan);
      return;
    }

    // Wrong book: say which one it is, so the librarian can find the right one.
    String scannedName = code.trim();
    try {
      final other = await ref
          .read(librarianRepositoryProvider)
          .fetchBookById(code.trim());
      if (other != null) scannedName = '"${other.title}" (${other.id})';
    } catch (_) {
      // keep the raw code
    }
    if (!mounted) return;
    setState(
      () => _error =
          'Wrong book. You scanned $scannedName, but this return is for '
          '"${widget.issue.bookTitle}" (${widget.issue.bookId}).',
    );
    // brief pause so the same wrong QR is not re-processed every frame
    await Future<void>.delayed(const Duration(seconds: 2));
    _checking = false;
  }

  Future<void> _manualEntry() async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualBookIdDialog(),
    );
    if (typed == null || !mounted) return;

    if (!bookCodeMatches(typed, widget.issue.bookId)) {
      setState(
        () => _error =
            'Book ID "$typed" does not match this return '
            '("${widget.issue.bookTitle}", ${widget.issue.bookId}).',
      );
      return;
    }

    final issue = widget.issue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm return'),
        content: Text(
          'Return "${issue.bookTitle}" (${issue.bookId}) from ${issue.studentName} '
          '(${issue.registrationNumber})?\n\nThis return will be recorded as entered manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Return book'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      Navigator.of(context).pop(ReturnMethod.manual);
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final due = DateFormat('dd MMM yyyy').format(issue.expiryDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan the book to return')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.cardBackground,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    issue.bookTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${issue.bookId} · ${issue.studentName} (${issue.registrationNumber}) · due $due',
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 12.5,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _manualEntry,
                    icon: const Icon(Icons.keyboard_outlined, size: 18),
                    label: const Text("Can't scan? Enter the book ID"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBookIdDialog extends ConsumerStatefulWidget {
  const _ManualBookIdDialog();

  @override
  ConsumerState<_ManualBookIdDialog> createState() =>
      _ManualBookIdDialogState();
}

class _ManualBookIdDialogState extends ConsumerState<_ManualBookIdDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog =
        ref.watch(librarianBooksProvider).valueOrNull ?? const <BookModel>[];
    final hits = searchBooks(catalog, _controller.text);
    return AlertDialog(
      title: const Text('Enter the book ID'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Part of the Book ID or title',
                helperText: 'Pick the book from the list, or type the full ID.',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            if (hits.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    key: const Key('return-book-suggestions'),
                    shrinkWrap: true,
                    children: [
                      for (final b in hits.take(20))
                        ListTile(
                          dense: true,
                          title: Text(b.title, overflow: TextOverflow.ellipsis),
                          subtitle: Text(b.id),
                          onTap: () => Navigator.pop(context, b.id),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Check'),
        ),
      ],
    );
  }
}
