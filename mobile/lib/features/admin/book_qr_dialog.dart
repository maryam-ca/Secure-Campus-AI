import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows the QR code for one book. The code holds exactly the book ID, which is
/// what the Librarian's scanner looks up, so a new book needs nothing else:
/// print this (or take a screenshot) and stick it on the book.
Future<void> showBookQrDialog(
  BuildContext context, {
  required String id,
  required String title,
  String author = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Book QR code'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  key: const Key('book-qr'),
                  data: id,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                id,
                key: const Key('book-qr-id'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(title, textAlign: TextAlign.center),
              if (author.isNotEmpty) Text(author, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'The librarian scans this code to issue or return the book. '
                'Print this page (Ctrl+P) or take a screenshot and stick it on the book.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
