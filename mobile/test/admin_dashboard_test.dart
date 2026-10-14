import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_dashboard_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/app_user.dart';
import 'package:securecampus/models/issue_report_model.dart';
import 'package:securecampus/core/constants/roles.dart';
import 'package:securecampus/providers/admin_navigation_provider.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/auth_provider.dart';
import 'package:securecampus/providers/issue_report_providers.dart';
import 'package:securecampus/providers/librarian_providers.dart';

AdminDashboardStats _stats({int alerts = 2, String bus = 'Idle (last known position 3 days ago)'}) => AdminDashboardStats(
      totalStudents: 10,
      todayAttendance: 4,
      todayGateEntries: 7,
      openUnknownAlerts: alerts,
      totalBooks: 5,
      issuedBooks: 2,
      busStatus: bus,
    );

const _books = [
  BookModel(id: 'B1', title: 'Algorithms', author: 'A', category: 'CS', available: true),
  BookModel(id: 'B2', title: 'Networks', author: 'B', category: 'CS', available: true, locked: true, lockReason: 'safe'),
  BookModel(id: 'B3', title: 'Databases', author: 'C', category: 'CS', available: false),
];

LibrarianIssueRow _overdueLoan() => LibrarianIssueRow(
      id: '1',
      bookId: 'B3',
      bookTitle: 'Databases',
      studentId: 's1',
      studentName: 'Ayesha Khan',
      registrationNumber: 'FA23-BSE-001',
      issueDate: DateTime.now().subtract(const Duration(days: 20)),
      expiryDate: DateTime.now().subtract(const Duration(days: 3)),
      returned: false,
    );

IssueReportModel _report() => const IssueReportModel(
      id: 'r1',
      issueId: 'i1',
      bookId: 'B3',
      bookTitle: 'Databases',
      studentId: 's1',
      studentName: 'Ayesha Khan',
      registrationNumber: 'FA23-BSE-001',
      note: '',
      status: 'NEW',
      createdAt: null,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AdminDashboardStats? stats,
  List<LibrarianIssueRow> loans = const [],
  List<IssueReportModel> reports = const [],
  bool statsFail = false,
}) async {
  // a typical phone: 360 x 780 logical pixels
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    dashboardStatsProvider.overrideWith((ref) async {
      if (statsFail) throw Exception('boom');
      return stats ?? _stats();
    }),
    booksProvider.overrideWith((ref) => Stream.value(_books)),
    activeIssuesProvider.overrideWith((ref) => Stream.value(loans)),
    issueReportsProvider.overrideWith((ref) => Stream.value(reports)),
    currentAppUserProvider.overrideWith((ref) => Stream.value(const AppUser(
          uid: 'a1',
          email: 'admin@securecampus.edu.pk',
          name: 'Campus Admin',
          role: UserRole.admin,
          active: true,
        ))),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: AdminDashboardScreen())),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// The dashboard is a lazily built list: scroll from the top until [f] is on screen.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(f, 150, scrollable: scrollable);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _reveal(tester, f);
  await tester.tap(f);
  await tester.pump();
}

void main() {
  testWidgets('shows the greeting, the groups and every number', (tester) async {
    await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    expect(find.textContaining('Campus Admin'), findsOneWidget);
    expect(find.text('Campus today'), findsOneWidget);
    expect(find.text('Library'), findsNWidgets(2)); // the quick action and the section title
    await _reveal(tester, find.text('Transport'));
    expect(find.text('Transport'), findsOneWidget);

    for (final label in [
      'Total Students',
      "Today's Attendance",
      "Today's Gate Entries",
      'Unknown Alerts (open)',
      'Library Books',
      'Issued Books',
      'Overdue Books',
      'Locked Books',
      'Bus Status',
    ]) {
      await _reveal(tester, find.text(label));
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('nothing overflows on a phone, even with a long bus status', (tester) async {
    await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);
    expect(tester.takeException(), isNull);
    // the bus status is shown in full, not cut to "Idle (last known ..."
    await _reveal(tester, find.text('Bus Status'));
    expect(find.textContaining('3 days ago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Needs attention" lists open alerts, overdue books and new reports', (tester) async {
    await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('2 unknown-person alerts to review'), findsOneWidget);
    expect(find.text('1 overdue book'), findsOneWidget);
    expect(find.text('1 new student report on library issues'), findsOneWidget);
    expect(find.textContaining('All clear'), findsNothing);
  });

  testWidgets('shows "All clear" when nothing needs attention', (tester) async {
    await _pump(tester, stats: _stats(alerts: 0));

    expect(find.textContaining('All clear'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('attention items open the right section; reports opens the Reports tab', (tester) async {
    final c = await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    await _tap(tester, find.text('2 unknown-person alerts to review'));
    expect(c.read(adminSectionProvider), AdminSection.gateSecurity);

    c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
    await _tap(tester, find.text('1 overdue book'));
    expect(c.read(adminSectionProvider), AdminSection.library);
    expect(c.read(adminLibraryTabProvider), 0);

    c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
    await _tap(tester, find.text('1 new student report on library issues'));
    expect(c.read(adminSectionProvider), AdminSection.library);
    expect(c.read(adminLibraryTabProvider), 1);
  });

  testWidgets('every stat card opens its section when tapped', (tester) async {
    final c = await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    final taps = <String, int>{
      'Total Students': AdminSection.students,
      'Library Books': AdminSection.library,
      'Issued Books': AdminSection.library,
      'Overdue Books': AdminSection.library,
      'Locked Books': AdminSection.library,
      'Bus Status': AdminSection.bus,
      "Today's Gate Entries": AdminSection.gateSecurity,
      'Unknown Alerts (open)': AdminSection.gateSecurity,
      "Today's Attendance": AdminSection.gateSecurity,
    };

    for (final entry in taps.entries) {
      c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
      await _tap(tester, find.text(entry.key));
      expect(c.read(adminSectionProvider), entry.value, reason: 'card "${entry.key}"');
    }
  });

  testWidgets('quick actions open Students, Library, Security and Camera', (tester) async {
    final c = await _pump(tester);

    final taps = <String, int>{
      'Students': AdminSection.students,
      'Security': AdminSection.gateSecurity,
      'Camera': AdminSection.camera,
    };
    for (final entry in taps.entries) {
      c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
      await _tap(tester, find.text(entry.key));
      expect(c.read(adminSectionProvider), entry.value, reason: 'quick action "${entry.key}"');
    }
  });

  testWidgets('a failed load shows a plain message with Retry, not raw error text', (tester) async {
    await _pump(tester, statsFail: true);

    expect(find.text('Could not load the dashboard.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });
}
