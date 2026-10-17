import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_nav.dart';
import 'package:securecampus/core/widgets/portal_sidebar.dart';
import 'package:securecampus/providers/admin_navigation_provider.dart';

Future<List<String>> _pump(WidgetTester tester, {String selected = AdminSection.dashboard}) async {
  tester.view.physicalSize = const Size(810, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final picked = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PortalSidebarMenu(nav: AdminNav.nav, selectedId: selected, onSelect: picked.add),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('shows the main modules; sub-modules start collapsed', (tester) async {
    await _pump(tester);

    for (final label in ['Dashboard', 'User Management', 'Academics', 'Library', 'Transport', 'Lost & Found', 'Phase 2']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Students'), findsNothing);
    expect(find.text('Catalog'), findsNothing);
    expect(find.text('Under development'), findsOneWidget);
  });

  testWidgets('tapping a main module expands and collapses its sub-modules', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('toggle-Library')));
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-Library')));
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsNothing);
  });

  testWidgets('a sub-module selects its own page id', (tester) async {
    final picked = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('toggle-Library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    expect(picked, [AdminSection.libraryReports]);
  });

  testWidgets('tapping a module name opens its first page and expands it', (tester) async {
    final picked = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('group-Library')));
    await tester.pumpAndSettle();
    expect(picked, ['group.library']);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('the group holding the open page starts expanded', (tester) async {
    await _pump(tester, selected: AdminSection.bus);
    expect(find.text('Buses'), findsOneWidget);
    expect(find.text('Catalog'), findsNothing);
  });

  testWidgets('Phase 2 modules are listed but cannot be clicked', (tester) async {
    final picked = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('group-Phase 2')));
    await tester.pumpAndSettle();
    expect(picked, isEmpty); // Phase 2 has no first page
    for (final label in ['Iris Recognition', 'Class Attendance', 'Gate & Security', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: label);
      await tester.tap(find.text(label));
    }
    expect(picked, isEmpty);
  });

  test('every Phase 1 item has a page and every Phase 2 item does not', () {
    for (final g in AdminNav.groups) {
      for (final i in g.items) {
        expect(i.enabled, isTrue, reason: i.id);
      }
    }
    for (final i in AdminNav.phase2.items) {
      expect(i.enabled, isFalse, reason: i.id);
    }
    final ids = [for (final g in AdminNav.nav.allGroups) for (final i in g.items) i.id];
    expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
  });

  testWidgets('opening one module closes the one that was open', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('toggle-Library')));
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-User Management')));
    await tester.pumpAndSettle();
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Catalog'), findsNothing); // Library closed itself

    // also when opened by clicking the name
    await tester.tap(find.byKey(const ValueKey('group-Library')));
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
  });
}
