import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/security/security_dashboard_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/auth_provider.dart';

LostCardReportModel _card(String id, {bool resolved = false}) => LostCardReportModel(
      id: id,
      studentNameGuess: 'Ayesha Khan',
      registrationNumberGuess: 'FA23-BSE-001',
      location: 'Library',
      description: '',
      notified: false,
      createdAt: DateTime(2026, 10, 17, 9),
      status: resolved ? 'RESOLVED' : 'OPEN',
      resolvedAt: resolved ? DateTime.now() : null,
    );

Future<void> _pump(WidgetTester tester, List<LostCardReportModel> cards) async {
  tester.view.physicalSize = const Size(3000, 1800); // sidebar visible
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
      lostCardReportsProvider.overrideWith((ref) => Stream.value(cards)),
    ],
    child: const MaterialApp(home: SecurityDashboardScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Security opens on Lost Cards (Phase 1); no Book Reports', (tester) async {
    await _pump(tester, [_card('1')]);

    expect(find.byKey(const ValueKey('nav-lost-cards')), findsOneWidget);
    expect(find.byKey(const ValueKey('lost-1')), findsOneWidget); // the report is on screen
    expect(find.text('Book Reports'), findsNothing);
  });

  testWidgets('Gate & Security pages sit under Phase 2, locked', (tester) async {
    await _pump(tester, const []);

    await tester.tap(find.byKey(const ValueKey('toggle-Phase 2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-entries')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-alerts')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-alerts')));
    await tester.tap(find.byKey(const ValueKey('nav-entries')));
    await tester.pumpAndSettle();
    expect(find.text('No lost-card reports.'), findsOneWidget); // still on Lost Cards
  });

  testWidgets('open found-card reports show as a live count on the sidebar', (tester) async {
    await _pump(tester, [_card('1'), _card('2'), _card('3', resolved: true)]);

    final tile = find.byKey(const ValueKey('nav-lost-cards'));
    expect(find.descendant(of: tile, matching: find.byType(Badge)), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('2')), findsOneWidget);
  });

  testWidgets('Security cannot resolve or change a report: no action buttons', (tester) async {
    await _pump(tester, [_card('1')]);

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
