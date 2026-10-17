import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/constants/roles.dart';
import 'package:securecampus/features/admin/admin_home_shell.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/app_user.dart';
import 'package:securecampus/providers/admin_navigation_provider.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/auth_provider.dart';
import 'package:securecampus/providers/issue_report_providers.dart';
import 'package:securecampus/providers/librarian_providers.dart';

Future<ProviderContainer> _pump(WidgetTester tester, String page) async {
  tester.view.physicalSize = const Size(3000, 1800); // wide: sidebar + page
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    dashboardStatsProvider.overrideWith((ref) async => const AdminDashboardStats(
          totalStudents: 1,
          todayAttendance: 0,
          todayGateEntries: 0,
          openUnknownAlerts: 0,
          totalBooks: 1,
          issuedBooks: 0,
          busStatus: 'Idle',
        )),
    booksProvider.overrideWith((ref) => Stream.value(const <BookModel>[])),
    activeIssuesProvider.overrideWith((ref) => Stream.value(const <LibrarianIssueRow>[])),
    issueReportsProvider.overrideWith((ref) => Stream.value(const [])),
    currentAppUserProvider.overrideWith((ref) => Stream.value(const AppUser(
          uid: 'a1',
          email: 'admin@securecampus.edu.pk',
          name: 'Campus Admin',
          role: UserRole.admin,
          active: true,
        ))),
  ]);
  addTearDown(container.dispose);
  container.read(adminSectionProvider.notifier).state = page;
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: AdminHomeShell()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a module opens a first page that lists its sub-modules', (tester) async {
    await _pump(tester, 'group.library');

    expect(find.byKey(const ValueKey('card-library.catalog')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-library.reports')), findsOneWidget);
    expect(find.text('2 SUB-MODULES'), findsOneWidget);
    // header bar shows where you are
    expect(find.byKey(const ValueKey('crumb-home')), findsOneWidget);
  });

  testWidgets('tapping a sub-module card opens that page', (tester) async {
    final c = await _pump(tester, 'group.users');

    await tester.tap(find.byKey(const ValueKey('card-staff.driver')));
    expect(c.read(adminSectionProvider), AdminSection.staffDriver);
  });

  testWidgets('every non-dashboard page has a way back to the dashboard', (tester) async {
    final c = await _pump(tester, 'group.transport');

    expect(find.byKey(const ValueKey('home-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('crumb-home')));
    expect(c.read(adminSectionProvider), AdminSection.dashboard);

    c.read(adminSectionProvider.notifier).state = 'group.academics';
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-button')));
    expect(c.read(adminSectionProvider), AdminSection.dashboard);
  });

  testWidgets('the dashboard has no header bar or home button', (tester) async {
    await _pump(tester, AdminSection.dashboard);

    expect(find.byKey(const ValueKey('home-button')), findsNothing);
    expect(find.byKey(const ValueKey('crumb-home')), findsNothing);
  });

  testWidgets('tapping the logo / app name returns to the dashboard', (tester) async {
    final c = await _pump(tester, 'group.transport');

    await tester.tap(find.byKey(const ValueKey('brand-home')));
    expect(c.read(adminSectionProvider), AdminSection.dashboard);
  });
}
