import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/lost_card_match.dart';
import 'package:securecampus/features/admin/admin_lost_cards_screen.dart';
import 'package:securecampus/features/common/found_card_report_screen.dart';
import 'package:securecampus/features/security/security_dashboard_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final List<String> resolved = [];
  final List<String> notified = [];
  final List<String> deleted = [];

  @override
  Future<void> resolveLostCardReport(String reportId) async => resolved.add(reportId);

  @override
  Future<void> deleteLostCardReport(String reportId) async => deleted.add(reportId);

  @override
  Future<bool> notifyStudentCardFound(LostCardReportModel report) async {
    notified.add(report.id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LostCardReportModel _report(
  String id, {
  String name = 'Ayesha Khan',
  String reg = 'FA23-BSE-001',
  String status = 'OPEN',
  DateTime? resolvedAt,
}) =>
    LostCardReportModel(
      id: id,
      studentNameGuess: name,
      registrationNumberGuess: reg,
      location: 'Library',
      description: '',
      notified: false,
      createdAt: DateTime(2026, 10, 17, 9),
      status: status,
      resolvedAt: resolvedAt,
    );

void main() {
  group('matchCard', () {
    test('verified when every word given is in the registered name, any case', () {
      expect(matchCard(registeredName: 'Ayesha Bibi Khan', enteredName: 'ayesha KHAN'), CardMatch.verified);
    });
    test('name mismatch when the name is someone else or empty', () {
      expect(matchCard(registeredName: 'Ayesha Khan', enteredName: 'Sara Ali'), CardMatch.nameMismatch);
      expect(matchCard(registeredName: 'Ayesha Khan', enteredName: '  '), CardMatch.nameMismatch);
    });
    test('unknown student when the registration number is not registered', () {
      expect(matchCard(registeredName: null, enteredName: 'Ayesha Khan'), CardMatch.unknownStudent);
    });
    test('registration numbers are compared upper case', () {
      expect(normalizeRegistration(' fa23-bse-001 '), 'FA23-BSE-001');
    });
  });

  group('who sees a report', () {
    final now = DateTime(2026, 10, 18, 12);
    test('open reports are always visible to Security', () {
      expect(_report('1').visibleToSecurity(now), isTrue);
    });
    test('a resolved report stays visible for a day, then disappears', () {
      final fresh = _report('2', status: 'RESOLVED', resolvedAt: now.subtract(const Duration(hours: 3)));
      final old = _report('3', status: 'RESOLVED', resolvedAt: now.subtract(const Duration(hours: 30)));
      expect(fresh.visibleToSecurity(now), isTrue);
      expect(old.visibleToSecurity(now), isFalse);
    });
  });

  group('finder form', () {
    testWidgets('name and registration number are required and not marked optional', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: FoundCardReportScreen())));
      await tester.pump();

      expect(find.textContaining('if known'), findsNothing);
      expect(find.textContaining('if visible'), findsNothing);

      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      expect(find.textContaining('Required - the name'), findsOneWidget);
      expect(find.textContaining('Required - the number'), findsOneWidget);
    });
  });

  group('Admin Lost Cards', () {
    Future<_FakeRepo> pump(WidgetTester tester, List<LostCardReportModel> reports, Map<String, String?> students) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = _FakeRepo();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          lostCardReportsProvider.overrideWith((ref) => Stream.value(reports)),
          registeredNameProvider.overrideWith((ref, reg) async => students[reg]),
        ],
        child: const MaterialApp(home: Scaffold(body: AdminLostCardsScreen())),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows whether each report matches a real student; Notify only when it does', (tester) async {
      final repo = await pump(
        tester,
        [
          _report('ok'),
          _report('bad-name', name: 'Sara Ali', reg: 'FA23-BSE-002'),
          _report('no-student', reg: 'XX99-ZZZ-999'),
        ],
        {'FA23-BSE-001': 'Ayesha Khan', 'FA23-BSE-002': 'Mehak Fatima'},
      );

      expect(find.text('Verified: matches Ayesha Khan'), findsOneWidget);
      expect(find.text('Name does not match the student with this registration number'), findsOneWidget);
      expect(find.text('No student has this registration number'), findsOneWidget);

      ElevatedButton notify(String id) => tester.widget<ElevatedButton>(find.byKey(ValueKey('notify-$id')));
      expect(notify('ok').onPressed, isNotNull);
      expect(notify('bad-name').onPressed, isNull);
      expect(notify('no-student').onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('notify-ok')));
      await tester.pump();
      expect(repo.notified, ['ok']);
    });

    testWidgets('Admin can delete a report that matches no student, and only those', (tester) async {
      final repo = await pump(
        tester,
        [
          _report('ok'),
          _report('bad-name', name: 'Sara Ali', reg: 'FA23-BSE-002'),
          _report('no-student', reg: 'XX99-ZZZ-999'),
        ],
        {'FA23-BSE-001': 'Ayesha Khan', 'FA23-BSE-002': 'Mehak Fatima'},
      );

      expect(find.byKey(const ValueKey('delete-ok')), findsNothing); // verified: kept
      expect(find.byKey(const ValueKey('delete-bad-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-no-student')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('delete-no-student')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['no-student']);
    });

    testWidgets('Admin resolves after confirming; resolved reports are marked and have no actions', (tester) async {
      final repo = await pump(
        tester,
        [_report('a'), _report('b', status: 'RESOLVED', resolvedAt: DateTime(2026, 10, 17, 10))],
        {'FA23-BSE-001': 'Ayesha Khan'},
      );

      expect(find.text('Resolved'), findsOneWidget);
      expect(find.byKey(const ValueKey('resolve-b')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('resolve-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolve'));
      await tester.pumpAndSettle();
      expect(repo.resolved, ['a']);
    });
  });

  testWidgets('Security sees open reports and recently resolved ones, read only', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lostCardReportsProvider.overrideWith((ref) => Stream.value([
              _report('open'),
              _report('fresh', status: 'RESOLVED', resolvedAt: now.subtract(const Duration(hours: 2))),
              _report('old', status: 'RESOLVED', resolvedAt: now.subtract(const Duration(days: 3))),
            ])),
      ],
      child: const MaterialApp(home: Scaffold(body: LostCardsView())),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lost-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('lost-fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('lost-old')), findsNothing); // disappeared
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing); // no actions for Security
  });
}
