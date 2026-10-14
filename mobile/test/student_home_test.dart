import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/widgets/animated_shield_logo.dart';
import 'package:securecampus/features/student/student_dashboard_screen.dart';
import 'package:securecampus/features/student/widgets/bus_assignment_section.dart';
import 'package:securecampus/features/student/widgets/student_home_section.dart';
import 'package:securecampus/models/dashboard_models.dart';
import 'package:securecampus/models/student_model.dart';
import 'package:securecampus/providers/student_providers.dart';

final _now = DateTime(2026, 10, 14, 12, 0);

BusAssignmentModel _bus({bool active = true, int? eta, Duration age = const Duration(seconds: 20)}) => BusAssignmentModel(
      busId: 'BUS-001',
      stopId: 's1',
      stopName: 'Block A',
      tripActive: active,
      etaMinutes: eta,
      statusUpdatedAt: _now.subtract(age),
    );

LibraryIssueModel _loan(String title, {required int dueInDays, bool returned = false}) => LibraryIssueModel(
      id: title,
      bookId: 'B-$title',
      bookTitle: title,
      issueDate: _now.subtract(const Duration(days: 10)),
      expiryDate: _now.add(Duration(days: dueInDays)),
      returned: returned,
      returnedAt: returned ? _now.subtract(const Duration(days: 2)) : null,
    );

AppNotification _note(String id, {bool read = false}) =>
    AppNotification(id: id, title: 't', message: 'm', type: 'SYSTEM', isRead: read, createdAt: _now);

const _student = StudentModel(
  uid: 's1',
  registrationNumber: 'FA23-BSE-007',
  name: 'Mehak Fatima',
  program: 'BSE',
  semester: 5,
  email: 'm@x.edu',
  courseIds: ['SE', 'AI'],
  irisEnrolled: false,
);

List<Override> _overrides({
  List<LibraryIssueModel> loans = const [],
  List<AppNotification> notes = const [],
  BusAssignmentModel? bus,
  AttendanceOverall? attendance = const AttendanceOverall(present: 8, total: 10, courses: 2),
}) =>
    [
      studentProfileProvider.overrideWith((ref) => Stream.value(_student)),
      libraryIssuesProvider.overrideWith((ref) => Stream.value(loans)),
      studentNotificationsProvider.overrideWith((ref) => Stream.value(notes)),
      busAssignmentProvider.overrideWith((ref) => Stream.value(bus)),
      overallAttendanceProvider.overrideWithValue(attendance),
    ];

void main() {
  group('BusAssignmentModel.tripInfo', () {
    BusTripInfo info(BusAssignmentModel b) => b.tripInfo(_now);

    test('no trip, or a status that was never written', () {
      expect(info(_bus(active: false, eta: 12)).level, BusTripLevel.idle);
      expect(info(const BusAssignmentModel(busId: 'b', stopId: 's', stopName: 'x')).level, BusTripLevel.idle);
    });

    test('a status older than 3 minutes is stale, so it never claims the bus is on its way', () {
      final stale = info(_bus(eta: 12, age: const Duration(minutes: 4)));
      expect(stale.level, BusTripLevel.idle);
      expect(stale.text, 'No trip in progress right now.');
      expect(info(_bus(eta: 12, age: const Duration(minutes: 2))).level, BusTripLevel.getReady);
    });

    test('wording follows the 20 and 10 minute reminders', () {
      expect(info(_bus(eta: 35)).level, BusTripLevel.onTheWay);
      expect(info(_bus(eta: 35)).text, 'On its way - about 35 min from your stop.');
      expect(info(_bus(eta: 20)).level, BusTripLevel.getReady);
      expect(info(_bus(eta: 15)).text, 'About 15 min from your stop - get ready.');
      expect(info(_bus(eta: 10)).level, BusTripLevel.headOut);
      expect(info(_bus(eta: 8)).text, 'About 8 min from your stop - head to your pickup point now.');
      expect(info(_bus(eta: 1)).text, 'Your bus is arriving now.');
    });
  });

  test('LibraryIssueModel.daysUntilDue counts whole days, negative once overdue', () {
    expect(_loan('a', dueInDays: 3).daysUntilDue(_now), 3);
    expect(_loan('a', dueInDays: 0).daysUntilDue(_now), 0);
    expect(_loan('a', dueInDays: -2).daysUntilDue(_now), -2);
  });

  group('BusStatusBanner', () {
    testWidgets('shows the status sentence, and goes back to idle when it goes stale', (tester) async {
      var clock = _now;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BusStatusBanner(assignment: _bus(eta: 15), clock: () => clock)),
      ));
      expect(find.text('About 15 min from your stop - get ready.'), findsOneWidget);

      clock = _now.add(const Duration(minutes: 5)); // the service stopped refreshing it
      await tester.pump(const Duration(seconds: 31)); // the banner re-checks every 30 s
      expect(find.text('No trip in progress right now.'), findsOneWidget);
    });
  });

  group('StudentHomeSection', () {
    Future<List<int>> pump(WidgetTester tester, List<Override> overrides) async {
      tester.view.physicalSize = const Size(1080, 2220); // 360 x 740
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final opened = <int>[];
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Scaffold(body: StudentHomeSection(onOpenTab: opened.add, now: _now)),
        ),
      ));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('header shows the real logo, the student and their details', (tester) async {
      await pump(tester, _overrides());
      expect(find.byType(AnimatedShieldLogo), findsOneWidget);
      expect(find.text('Mehak Fatima'), findsOneWidget);
      expect(find.text('FA23-BSE-007 · BSE · Semester 5'), findsOneWidget);
    });

    testWidgets('nothing needs attention: All clear and the four numbers', (tester) async {
      await pump(tester, _overrides(loans: [_loan('Algorithms', dueInDays: 9)], bus: _bus(active: false)));

      expect(find.textContaining('All clear'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('8 of 10 classes'), findsOneWidget);
      expect(find.text('Books issued'), findsOneWidget);
      expect(find.textContaining('next due'), findsOneWidget);
      expect(find.text('Unread alerts'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Campus Bus - Block A'), findsOneWidget);
      expect(find.text('No trip in progress right now.'), findsOneWidget);
    });

    testWidgets('overdue, due-soon, unread and a close bus each get an attention row', (tester) async {
      await pump(
        tester,
        _overrides(
          loans: [_loan('Old', dueInDays: -3), _loan('Soon', dueInDays: 1), _loan('Later', dueInDays: 9)],
          notes: [_note('1'), _note('2'), _note('3', read: true)],
          bus: _bus(eta: 8),
        ),
      );

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('1 book is overdue - please return it'), findsOneWidget);
      expect(find.text('1 book due within 2 days'), findsOneWidget);
      expect(find.text('2 unread alerts'), findsOneWidget);
      expect(find.textContaining('Bus: About 8 min'), findsOneWidget);
      expect(find.textContaining('All clear'), findsNothing);
      expect(find.text('1 overdue'), findsOneWidget); // note under "Books issued"
    });

    testWidgets('a far-away bus is not an attention item', (tester) async {
      await pump(tester, _overrides(bus: _bus(eta: 40)));
      expect(find.textContaining('Bus: '), findsNothing);
      expect(find.text('On its way - about 40 min from your stop.'), findsOneWidget);
    });

    testWidgets('fits one phone screen with every attention row showing', (tester) async {
      await pump(
        tester,
        _overrides(
          loans: [_loan('Old', dueInDays: -3), _loan('Soon', dueInDays: 1)],
          notes: [_note('1')],
          bus: _bus(eta: 8),
        ),
      );
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(position.maxScrollExtent, 0, reason: 'student home should not need scrolling');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiles and rows open the matching tab', (tester) async {
      final opened = await pump(
        tester,
        _overrides(loans: [_loan('Old', dueInDays: -3)], notes: [_note('1')], bus: _bus(eta: 8)),
      );

      await tester.tap(find.text('Attendance'));
      await tester.tap(find.text('Books issued'));
      await tester.tap(find.text('Unread alerts'));
      await tester.tap(find.text('Campus Bus - Block A'));
      await tester.tap(find.text('1 book is overdue - please return it'));
      expect(opened, [StudentTab.attendance, StudentTab.library, StudentTab.alerts, StudentTab.bus, StudentTab.library]);
    });

    testWidgets('with no bus assignment it says so', (tester) async {
      await pump(tester, _overrides(bus: null));
      expect(find.text('You are not assigned to a bus.'), findsOneWidget);
    });
  });

  group('StudentDashboardScreen', () {
    Future<void> pumpDash(WidgetTester tester, List<Override> overrides) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: StudentDashboardScreen())));
      await tester.pumpAndSettle();
    }

    testWidgets('five tabs with Home first and an unread badge on Alerts', (tester) async {
      await pumpDash(tester, _overrides(notes: [_note('1'), _note('2'), _note('3', read: true)]));

      for (final label in ['Home', 'Attendance', 'Bus', 'Library', 'Alerts']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.byType(Badge), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);
      expect(find.text('Mehak Fatima'), findsOneWidget); // the Home tab is showing
    });

    testWidgets('no badge when every alert has been read', (tester) async {
      await pumpDash(tester, _overrides(notes: [_note('1', read: true)]));
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('Library tab lists current books and the returned-books history', (tester) async {
      await pumpDash(tester, _overrides(loans: [_loan('Algorithms', dueInDays: 5), _loan('Networks', dueInDays: -9, returned: true)]));

      // these tabs have a looping header animation, so pumpAndSettle would never finish
      await tester.tap(find.text('Library').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.text('Returned books (1)'), findsOneWidget);

      await tester.tap(find.text('Returned books (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Networks'), findsOneWidget);
      expect(find.textContaining('returned'), findsWidgets);
    });
  });
}
