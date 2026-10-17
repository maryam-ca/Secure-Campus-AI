import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/widgets/animated_shield_logo.dart';
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

AdminDashboardStats _stats({String bus = 'Idle (last known position 3 days ago)'}) => AdminDashboardStats(
      totalStudents: 10,
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
  // a typical phone: 360 x 740 logical pixels
  tester.view.physicalSize = const Size(1080, 2220);
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
  testWidgets('shows the greeting, the Phase 1 numbers and greyed-out Phase 2 cards, with nothing repeated', (tester) async {
    await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    expect(find.textContaining('Campus Admin'), findsOneWidget);
    expect(find.byType(AnimatedShieldLogo), findsOneWidget); // the real app logo
    expect(find.text('SecureCampus'), findsOneWidget);
    for (final label in ['Total Students', 'Library Books', 'Bus Status']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Phase 2 cards carry no number: nothing is invented for unbuilt features
    expect(find.text('PHASE 2'), findsOneWidget);
    expect(find.text('Under development'), findsNWidgets(3)); // heading + 2 cards
    for (final label in ['Attendance', 'Gate Entries']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('2 issued · 1 locked'), findsOneWidget); // library note: issued and locked together
    expect(find.text('10'), findsOneWidget); // total students

    // removed as duplicates / clutter
    for (final gone in ['Unknown Alerts (open)', 'Overdue Books', 'Locked Books', 'Issued Books', 'Campus today', 'Quick actions']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    // the side-menu shortcuts are gone too
    expect(find.text('Students'), findsNothing);
    expect(find.text('Camera'), findsNothing);
  });

  testWidgets('everything fits on one phone screen: no scrolling needed', (tester) async {
    await _pump(tester, loans: [_overdueLoan()], reports: [_report()]); // worst case: all 3 attention rows

    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.maxScrollExtent, 0, reason: 'dashboard should not need scrolling');
    expect(tester.takeException(), isNull);
    // every card is on screen without scrolling
    expect(find.text('Bus Status'), findsOneWidget);
    final bus = tester.getRect(find.text('Bus Status'));
    // the real screen also has a status bar (~28px) and the app bar (56px): ~650px left for the page
    expect(bus.bottom, lessThan(650), reason: 'bus card must end above the bottom of the real page area');
  });

  testWidgets('a long bus status is shown in full and nothing overflows', (tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('3 days ago'), findsOneWidget);
  });

  testWidgets('"Needs attention" lists overdue books and new reports', (tester) async {
    await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('1 overdue book'), findsOneWidget);
    expect(find.text('1 new student report on library issues'), findsOneWidget);
    expect(find.textContaining('All clear'), findsNothing);
  });

  testWidgets('shows "All clear" when nothing needs attention', (tester) async {
    await _pump(tester, stats: _stats());

    expect(find.textContaining('All clear'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('attention items open the right page; reports opens Library > Reports', (tester) async {
    final c = await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    await _tap(tester, find.text('1 overdue book'));
    expect(c.read(adminSectionProvider), AdminSection.libraryCatalog);

    c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
    await _tap(tester, find.text('1 new student report on library issues'));
    expect(c.read(adminSectionProvider), AdminSection.libraryReports);
  });

  testWidgets('every Phase 1 card opens its page; Phase 2 cards do nothing', (tester) async {
    final c = await _pump(tester, loans: [_overdueLoan()], reports: [_report()]);

    final taps = <String, String>{
      'Total Students': AdminSection.students,
      'Library Books': AdminSection.libraryCatalog,
      'Bus Status': AdminSection.bus,
    };

    for (final entry in taps.entries) {
      c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
      await _tap(tester, find.text(entry.key));
      expect(c.read(adminSectionProvider), entry.value, reason: 'card "${entry.key}"');
    }

    c.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
    await _tap(tester, find.text('Attendance'));
    await _tap(tester, find.text('Gate Entries'));
    expect(c.read(adminSectionProvider), AdminSection.dashboard);
  });

  testWidgets('a failed load shows a plain message with Retry, not raw error text', (tester) async {
    await _pump(tester, statsFail: true);

    expect(find.text('Could not load the dashboard.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });
}
