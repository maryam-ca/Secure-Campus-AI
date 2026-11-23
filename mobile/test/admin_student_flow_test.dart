import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_students_screen.dart';
import 'package:securecampus/models/course_model.dart';
import 'package:securecampus/models/student_model.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/providers/admin_student_providers.dart';
import 'package:securecampus/services/backend_api_service.dart';

class _FakeBackend extends BackendApiService {
  @override
  Future<Map<String, dynamic>> createAccount({
    required String email,
    required String name,
    required String role,
    Map<String, dynamic>? studentFields,
    String? password,
  }) async =>
      {'email': email, 'temporaryPassword': 'Temp-1234'};
}

StudentModel _s(String reg, String name, int sem) => StudentModel(
      uid: 'u-$reg',
      registrationNumber: reg,
      name: name,
      program: 'BSE',
      semester: sem,
      email: '${reg.toLowerCase()}@securecampus.edu.pk',
      courseIds: const [],
    );

final _students = [_s('FA23-BSE-001', 'Ayesha Khan', 5), _s('FA24-BSE-003', 'Bilal Ahmed', 3)];

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      allStudentsProvider.overrideWith((ref) => Stream.value(_students)),
      studentAccountActiveProvider.overrideWith((ref, uid) => Stream.value(true)),
      courseOptionsProvider.overrideWith((ref) async => const <CourseModel>[]),
      backendApiServiceProvider.overrideWithValue(_FakeBackend()),
    ],
    child: const MaterialApp(home: Scaffold(body: AdminStudentsScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing "All semesters" removes the semester filter', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Semester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semester 3').last);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 students'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsNothing);

    await tester.tap(find.text('Semester 3')); // the chip now names the semester
    await tester.pumpAndSettle();
    await tester.tap(find.text('All semesters'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2 students'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('Semester'), findsOneWidget); // chip back to its plain label
  });

  testWidgets('after a student is created, Done closes the credentials box', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Maryam');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'maryam@gmail.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Registration number (e.g. FA23-BSE-011)'), 'fa23-bse-032');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Student account created'), findsOneWidget);
    expect(find.textContaining('Temp-1234'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Student account created'), findsNothing);
    expect(find.text('Add Student'), findsOneWidget); // back on the list, nothing else closed
    expect(find.text('Ayesha Khan'), findsOneWidget);
  });
}
