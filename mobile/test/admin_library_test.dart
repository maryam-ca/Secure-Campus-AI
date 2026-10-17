import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_library_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/issue_report_model.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/issue_report_providers.dart';
import 'package:securecampus/providers/librarian_providers.dart';

const _books = [
  BookModel(id: 'B1', title: 'Algorithms', author: 'A', category: 'CS', available: true),
  BookModel(id: 'B2', title: 'Networks', author: 'B', category: 'CS', available: true, locked: true, lockReason: 'in safe'),
];

IssueReportModel _report(String id, {String status = 'NEW'}) => IssueReportModel(
      id: id,
      issueId: 'i$id',
      bookId: 'B1',
      bookTitle: 'Algorithms',
      studentId: 's$id',
      studentName: 'Ayesha Khan',
      registrationNumber: 'FA23-BSE-001',
      note: 'never took it',
      status: status,
      createdAt: null,
    );

Future<void> _pump(WidgetTester tester, {List<IssueReportModel> reports = const [], int initialTab = 0}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      booksProvider.overrideWith((ref) => Stream.value(_books)),
      librarianBooksProvider.overrideWith((ref) => Stream.value(_books)),
      activeIssuesProvider.overrideWith((ref) => Stream.value(const <LibrarianIssueRow>[])),
      issueReportsProvider.overrideWith((ref) => Stream.value(reports)),
    ],
    child: MaterialApp(home: Scaffold(body: AdminLibraryScreen(initialTab: initialTab))),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Catalog is the default page and has no tab bar of its own', (tester) async {
    await _pump(tester);

    expect(find.text('Algorithms'), findsOneWidget); // catalog content
    expect(find.text('Student reports'), findsNothing);
    // the header bar's chips switch pages, so there must be no second Catalog / Reports pair here
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('the Reports page shows the summary and the student reports', (tester) async {
    await _pump(tester, reports: [_report('1')], initialTab: 1);

    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Student reports'), findsOneWidget);
    expect(find.text('Issued now'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.textContaining('Ayesha Khan'), findsOneWidget);
    expect(find.text('Mark resolved'), findsOneWidget);
  });
}
