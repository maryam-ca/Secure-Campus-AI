import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:securecampus/core/utils/catalog_logic.dart';
import 'package:securecampus/features/admin/admin_library_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/issue_report_model.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/issue_report_providers.dart';
import 'package:securecampus/providers/librarian_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final saved = <String>[];

  @override
  Future<void> upsertBook(String id, String title, String author, String category) async => saved.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _books = [
  BookModel(id: 'BOOK-005', title: 'Software Engineering', author: 'Sommerville', category: 'CS', available: true),
];

Future<_FakeRepo> _pump(WidgetTester tester) async {
  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      booksProvider.overrideWith((ref) => Stream.value(_books)),
      librarianBooksProvider.overrideWith((ref) => Stream.value(_books)),
      activeIssuesProvider.overrideWith((ref) => Stream.value(const <LibrarianIssueRow>[])),
      issueReportsProvider.overrideWith((ref) => Stream.value(const <IssueReportModel>[])),
    ],
    child: const MaterialApp(home: Scaffold(body: AdminLibraryScreen())),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return repo;
}

void main() {
  group('nextBookId', () {
    test('is one more than the highest BOOK number', () {
      expect(nextBookId(['BOOK-001', 'BOOK-005', 'BOOK-003']), 'BOOK-006');
    });
    test('starts at BOOK-001 and ignores other formats', () {
      expect(nextBookId(const []), 'BOOK-001');
      expect(nextBookId(['B1', 'LIB/2024/7']), 'BOOK-001');
    });
    test('grows past 999 without breaking', () {
      expect(nextBookId(['BOOK-999']), 'BOOK-1000');
    });
  });

  testWidgets('Add Book fills in the next ID, saves, and shows the new book\'s QR code', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('Add Book'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'BOOK-006'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Operating Systems');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(repo.saved, ['BOOK-006']);
    expect(find.byKey(const Key('book-qr')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('book-qr-id'))).data, 'BOOK-006');
    expect(find.text('Operating Systems'), findsOneWidget);
  });

  testWidgets('an ID that is already used is refused, not overwritten', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('Add Book'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'BOOK-006'), 'book 005');
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Another');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(repo.saved, isEmpty);
    expect(find.byKey(const Key('book-id-error')), findsOneWidget);
    expect(find.byKey(const Key('book-qr')), findsNothing);
  });

  testWidgets('an existing book can show its QR code from the options menu', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Book options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show QR code'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('book-qr-id'))).data, 'BOOK-005');
    expect(find.byKey(const Key('book-qr-id')), findsOneWidget);
  });
}
