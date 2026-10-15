import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/catalog_logic.dart';
import 'package:securecampus/features/librarian/librarian_scan_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/librarian_providers.dart';

BookModel _b(String id, String title, {String author = 'Someone'}) =>
    BookModel(id: id, title: title, author: author, category: 'CS', available: true);

// Mixed ID formats on purpose: old and new.
final _books = [
  _b('BOOK-001', 'Introduction to Algorithms'),
  _b('BOOK-002', 'Computer Networking'),
  _b('LIB-CS-2026-014', 'Operating Systems', author: 'Silberschatz'),
  _b('LIB-CS-2026-015', 'Database Systems'),
];

void main() {
  group('searchBooks', () {
    test('part of the ID finds the book, whatever the format', () {
      expect(searchBooks(_books, '001').map((b) => b.id), ['BOOK-001']);
      expect(searchBooks(_books, '2026').map((b) => b.id), ['LIB-CS-2026-014', 'LIB-CS-2026-015']);
      expect(searchBooks(_books, 'cs-2026-014').map((b) => b.id), ['LIB-CS-2026-014']);
    });

    test('case, dashes and spaces are ignored', () {
      expect(searchBooks(_books, 'book 00').map((b) => b.id), ['BOOK-001', 'BOOK-002']);
      expect(searchBooks(_books, 'lib cs 2026 015').map((b) => b.id), ['LIB-CS-2026-015']);
    });

    test('title and author also match', () {
      expect(searchBooks(_books, 'algor').map((b) => b.id), ['BOOK-001']);
      expect(searchBooks(_books, 'silber').map((b) => b.id), ['LIB-CS-2026-014']);
    });

    test('fewer than two characters finds nothing; no match is empty', () {
      expect(searchBooks(_books, 'b'), isEmpty);
      expect(searchBooks(_books, ''), isEmpty);
      expect(searchBooks(_books, 'zzzz'), isEmpty);
    });
  });

  group('bookForCode', () {
    test('finds the exact book regardless of case, dashes and spaces', () {
      expect(bookForCode(_books, 'book-001')!.id, 'BOOK-001');
      expect(bookForCode(_books, ' LIB CS 2026 014 ')!.id, 'LIB-CS-2026-014');
    });

    test('a partial code is not a match (the librarian must pick)', () {
      expect(bookForCode(_books, '001'), isNull);
      expect(bookForCode(_books, ''), isNull);
    });

    test('ambiguous codes match nothing instead of the wrong book', () {
      final twins = [_b('AB-1', 'One'), _b('A-B1', 'Two')];
      expect(bookForCode(twins, 'ab1'), isNull);
    });
  });

  testWidgets('typing part of a book ID on the librarian screen lists matching books to pick', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [librarianBooksProvider.overrideWith((ref) => Stream.value(_books))],
      child: const MaterialApp(home: Scaffold(body: LibrarianScanScreen())),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '2026');
    await tester.pump();

    expect(find.byKey(const Key('book-suggestions')), findsOneWidget);
    expect(find.text('Operating Systems'), findsOneWidget);
    expect(find.text('Database Systems'), findsOneWidget);
    expect(find.text('Computer Networking'), findsNothing);
    expect(find.text('LIB-CS-2026-014 · Available'), findsOneWidget);
  });
}
