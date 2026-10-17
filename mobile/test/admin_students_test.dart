import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_student_overview_screen.dart';
import 'package:securecampus/features/admin/admin_students_screen.dart';
import 'package:securecampus/models/course_model.dart';
import 'package:securecampus/models/dashboard_models.dart';
import 'package:securecampus/models/student_model.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/admin_student_providers.dart';

StudentModel _s(String reg, String name, {int sem = 5, List<String> courses = const []}) => StudentModel(
      uid: 'u-$reg',
      registrationNumber: reg,
      name: name,
      program: 'BSE',
      semester: sem,
      email: '${reg.toLowerCase()}@securecampus.edu.pk',
      courseIds: courses,
    );

final _students = [
  _s('FA23-BSE-001', 'Ayesha Khan', sem: 5),
  _s('FA23-BSE-007', 'Mehak Fatima', sem: 5),
  _s('FA24-BSE-003', 'Bilal Ahmed', sem: 3),
];

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('Admin students list', () {
    Future<void> pump(WidgetTester tester, {bool accountActive = true}) async {
      await _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          allStudentsProvider.overrideWith((ref) => Stream.value(_students)),
          studentAccountActiveProvider.overrideWith((ref, uid) => Stream.value(accountActive)),
        ],
        child: const MaterialApp(home: Scaffold(body: AdminStudentsScreen())),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows every student and how many are shown, with no iris information', (tester) async {
      await pump(tester);

      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(find.text('Mehak Fatima'), findsOneWidget);
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.text('3 of 3 students'), findsOneWidget);
      expect(find.textContaining('Iris'), findsNothing); // iris is Phase 2
      expect(find.textContaining('enrolled'), findsNothing);
    });

    testWidgets('search finds a student by any part of the ID or the name', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), '007');
      await tester.pump();
      expect(find.text('Mehak Fatima'), findsOneWidget);
      expect(find.text('Ayesha Khan'), findsNothing);

      await tester.enterText(find.byType(TextField), 'bilal');
      await tester.pump();
      expect(find.text('Bilal Ahmed'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump();
      expect(find.text('No students match your search or filters.'), findsOneWidget);
    });

    testWidgets('the semester filter keeps only that semester', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Semester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester 3').last);
      await tester.pumpAndSettle();

      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.text('Ayesha Khan'), findsNothing);
      expect(find.text('1 of 3 students'), findsOneWidget);
    });

    testWidgets('the detail sheet offers Deactivate for an active account', (tester) async {
      await pump(tester, accountActive: true);

      await tester.tap(find.text('Mehak Fatima'));
      await tester.pumpAndSettle();
      expect(find.text('Account active'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Reactivate'), findsNothing);
      expect(find.text('Full details'), findsOneWidget);
    });

    testWidgets('a deactivated account can now be reactivated from the same sheet', (tester) async {
      await pump(tester, accountActive: false);

      await tester.tap(find.text('Mehak Fatima'));
      await tester.pumpAndSettle();
      expect(find.text('Account deactivated'), findsOneWidget);
      expect(find.text('Reactivate'), findsOneWidget);
      expect(find.text('Deactivate'), findsNothing);
    });
  });

  group('Student overview', () {
    testWidgets('shows profile, courses with attendance, loans and the bus stop', (tester) async {
      // a tall screen so the whole page is built at once (a ListView builds lazily)
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final student = _s('FA23-BSE-007', 'Mehak Fatima', courses: ['SE', 'AI']);
      final now = DateTime.now();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          studentAccountActiveProvider.overrideWith((ref, uid) => Stream.value(true)),
          courseOptionsProvider.overrideWith((ref) async => const [
                CourseModel(id: 'SE', name: 'Software Engineering'),
                CourseModel(id: 'AI', name: 'Artificial Intelligence'),
              ]),
          adminStudentLoansProvider.overrideWith((ref, uid) => Stream.value([
                LibraryIssueModel(
                    id: '1',
                    bookId: 'B1',
                    bookTitle: 'Algorithms',
                    issueDate: now.subtract(const Duration(days: 20)),
                    expiryDate: now.subtract(const Duration(days: 2)),
                    returned: false),
                LibraryIssueModel(
                    id: '2',
                    bookId: 'B2',
                    bookTitle: 'Networks',
                    issueDate: now.subtract(const Duration(days: 30)),
                    expiryDate: now.subtract(const Duration(days: 16)),
                    returned: true),
              ])),
          adminStudentBusProvider.overrideWith((ref, uid) =>
              Stream.value(const BusAssignmentModel(busId: 'BUS-001', stopId: 's1', stopName: 'Block A'))),
        ],
        child: MaterialApp(home: AdminStudentOverviewScreen(student: student)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mehak Fatima'), findsOneWidget);
      expect(find.text('Account active'), findsOneWidget);
      expect(find.textContaining('Iris'), findsNothing); // iris is Phase 2

      expect(find.text('Software Engineering'), findsOneWidget);
      expect(find.text('Artificial Intelligence'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing); // attendance is Phase 2

      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.textContaining('OVERDUE'), findsOneWidget);
      expect(find.text('1 book returned earlier'), findsOneWidget);

      expect(find.text('BUS-001 - stop: Block A'), findsOneWidget);
    });
  });
}
