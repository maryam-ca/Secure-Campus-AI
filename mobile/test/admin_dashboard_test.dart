import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_dashboard_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/admin_navigation_provider.dart';
import 'package:securecampus/providers/admin_providers.dart';

const _stats = AdminDashboardStats(
  totalStudents: 10,
  todayAttendance: 4,
  todayGateEntries: 7,
  openUnknownAlerts: 1,
  totalBooks: 5,
  issuedBooks: 2,
  busStatus: 'Idle',
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final container = ProviderContainer(overrides: [
    dashboardStatsProvider.overrideWith((ref) async => _stats),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: AdminDashboardScreen())),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('dashboard cards open their section when tapped', (tester) async {
    final container = await _pump(tester);
    expect(container.read(adminSectionProvider), AdminSection.dashboard);

    final taps = <String, int>{
      'Total Students': AdminSection.students,
      'Library Books': AdminSection.library,
      'Issued Books': AdminSection.library,
      'Bus Status': AdminSection.bus,
      "Today's Gate Entries": AdminSection.gateSecurity,
      'Unknown Alerts (open)': AdminSection.gateSecurity,
      "Today's Attendance": AdminSection.gateSecurity,
    };

    for (final entry in taps.entries) {
      container.read(adminSectionProvider.notifier).state = AdminSection.dashboard;
      final card = find.text(entry.key);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pump();
      expect(container.read(adminSectionProvider), entry.value, reason: 'card "${entry.key}"');
    }
  });
}
