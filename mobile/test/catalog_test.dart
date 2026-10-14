import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/catalog_logic.dart';
import 'package:securecampus/features/librarian/librarian_catalog_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/librarian_providers.dart';

BookModel _book(String id, String title, {bool available = true, bool locked = false, String reason = ''}) =>
    BookModel(
      id: id,
      title: title,
      author: 'Author $id',
      category: 'CS',
      available: available,
      locked: locked,
      lockReason: reason,
      lockedByName: locked ? 'Librarian One' : '',
    );

LibrarianIssueRow _loan(String id, String bookId, String title, String student, {required int dueInDays}) =>
    LibrarianIssueRow(
      id: id,
      bookId: bookId,
      bookTitle: title,
      studentId: 'u-$id',
      studentName: student,
      registrationNumber: 'FA23-BSE-00$id',
      issueDate: DateTime.now().subtract(const Duration(days: 9)),
      expiryDate: DateTime.now().add(Duration(days: dueInDays)),
      returned: false,
    );

// 5 books: two available, two issued (one of them overdue), one locked.
final _books = [
  _book('B1', 'Algorithms'),
  _book('B2', 'Networks'),
  _book('B3', 'Databases', available: false),
  _book('B4', 'Compilers', available: false),
  _book('B5', 'Cryptography', locked: true, reason: 'pages torn, kept in safe'),
];
final _loans = [
  _loan('1', 'B3', 'Databases', 'Ayesha Khan', dueInDays: 4),
  _loan('2', 'B4', 'Compilers', 'Bilal Ahmed', dueInDays: -3),
];

void main() {
  group('catalog logic', () {
    test('a book is available, issued or locked (locked wins)', () {
      expect(bookState(_book('x', 'x')), BookState.available);
      expect(bookState(_book('x', 'x', available: false)), BookState.issued);
      expect(bookState(_book('x', 'x', locked: true)), BookState.locked);
    });

    test('counts per sub-tab; overdue is a subset of issued', () {
      final c = catalogCounts(_books, _loans);
      expect([c.all, c.available, c.issued, c.overdue, c.locked], [5, 2, 2, 1, 1]);
      expect(c.forFilter(CatalogFilter.locked), 1);
    });

    test('book lists for All, Available, Locked, with search', () {
      expect(booksForFilter(_books, CatalogFilter.all, '').length, 5);
      expect(booksForFilter(_books, CatalogFilter.available, '').map((b) => b.id), ['B1', 'B2']);
      expect(booksForFilter(_books, CatalogFilter.locked, '').map((b) => b.id), ['B5']);
      expect(booksForFilter(_books, CatalogFilter.all, 'crypto').map((b) => b.id), ['B5']);
    });

    test('loan lists for Issued and Overdue, with search by student', () {
      expect(loansForFilter(_loans, CatalogFilter.issued, '').length, 2);
      expect(loansForFilter(_loans, CatalogFilter.overdue, '').map((l) => l.id), ['2']);
      expect(loansForFilter(_loans, CatalogFilter.issued, 'ayesh').map((l) => l.id), ['1']);
    });

    test('a book with no lock fields (older data) is simply not locked', () {
      final b = BookModel.fromMap('B9', {'title': 'Old', 'available': true});
      expect(b.locked, isFalse);
      expect(bookState(b), BookState.available);
    });
  });

  group('Catalog screen', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          librarianBooksProvider.overrideWith((ref) => Stream.value(_books)),
          activeIssuesProvider.overrideWith((ref) => Stream.value(_loans)),
        ],
        child: const MaterialApp(home: Scaffold(body: LibrarianCatalogScreen())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    String count(WidgetTester tester, CatalogFilter f) =>
        (tester.widget<Text>(find.byKey(ValueKey('catalog-count-${f.name}')))).data!;

    testWidgets('each sub-tab shows its quantity', (tester) async {
      await pump(tester);
      expect(
        [for (final f in CatalogFilter.values) count(tester, f)],
        ['5', '2', '2', '1', '1'], // All, Available, Issued, Overdue, Locked
      );
    });

    testWidgets('Locked tab lists the locked book with its reason and an Unlock button', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('catalog-tab-locked')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cryptography'), findsOneWidget);
      expect(find.textContaining('pages torn, kept in safe'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Algorithms'), findsNothing);
    });

    testWidgets('Overdue tab shows only the overdue loan, with its student', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('catalog-tab-overdue')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Bilal Ahmed'), findsOneWidget);
      expect(find.textContaining('Ayesha Khan'), findsNothing);
      expect(find.text('Return'), findsOneWidget);
    });

    testWidgets('Available tab hides issued and locked books', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('catalog-tab-available')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.text('Networks'), findsOneWidget);
      expect(find.text('Databases'), findsNothing);
      expect(find.text('Cryptography'), findsNothing);
    });
  });
}
