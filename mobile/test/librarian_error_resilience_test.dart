import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/common/issue_reports_screen.dart';
import 'package:securecampus/features/librarian/librarian_catalog_screen.dart';
import 'package:securecampus/features/librarian/librarian_reports_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/issue_report_providers.dart';
import 'package:securecampus/providers/librarian_providers.dart';

// Regression: reading a failed stream with `.value` rethrows inside build() and
// paints Flutter's red error screen. This happened when Firestore denied the
// reports query (rules not deployed yet). These screens must stay usable.

const _books = [
  BookModel(id: 'B1', title: 'Algorithms', author: 'A', category: 'CS', available: true),
];

Widget _app(Widget child, List<Override> overrides) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: child)));

final _denied = Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.');

void main() {
  testWidgets('Reports tab still builds when the reports and loans streams fail', (tester) async {
    await tester.pumpWidget(_app(const LibrarianReportsScreen(), [
      librarianBooksProvider.overrideWith((ref) => Stream.value(_books)),
      activeIssuesProvider.overrideWith((ref) => Stream<List<LibrarianIssueRow>>.error(_denied)),
      issueReportsProvider.overrideWith((ref) => Stream.error(_denied)),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Issued now'), findsOneWidget);
    expect(find.text('Student reports'), findsOneWidget);
  });

  testWidgets('Catalog still builds when the loans stream fails', (tester) async {
    await tester.pumpWidget(_app(const LibrarianCatalogScreen(), [
      librarianBooksProvider.overrideWith((ref) => Stream.value(_books)),
      activeIssuesProvider.overrideWith((ref) => Stream<List<LibrarianIssueRow>>.error(_denied)),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Algorithms'), findsOneWidget);
  });

  testWidgets('a denied reports query shows a plain message and a Retry button, not raw text', (tester) async {
    await tester.pumpWidget(_app(const IssueReportsScreen(), [
      issueReportsProvider.overrideWith((ref) => Stream.error(_denied)),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Student reports are not available yet.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('cloud_firestore'), findsNothing);
  });

  testWidgets('any other reports error says to check the connection', (tester) async {
    await tester.pumpWidget(_app(const IssueReportsScreen(), [
      issueReportsProvider.overrideWith((ref) => Stream.error(Exception('socket closed'))),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
