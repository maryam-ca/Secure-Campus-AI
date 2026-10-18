import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_courses_screen.dart';
import 'package:securecampus/models/admin_models.dart';
import 'package:securecampus/models/student_model.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/repositories/admin_repository.dart';

class _FakeRepo implements AdminRepository {
  final List<AdminCourseModel> saved = [];
  final List<String> deleted = [];
  bool failSaves = false;

  @override
  Future<void> upsertCourse(AdminCourseModel course) async {
    if (failSaves) throw Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.');
    saved.add(course);
  }

  @override
  Future<void> deleteCourse(String courseId) async => deleted.add(courseId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _courses = [
  AdminCourseModel(id: 'AI', name: 'Artificial Intelligence'),
  AdminCourseModel(id: 'SE', name: 'Software Engineering'),
];

StudentModel _student(List<String> courseIds) => StudentModel(
      uid: 'u1',
      registrationNumber: 'FA23-BSE-001',
      name: 'Ayesha Khan',
      program: 'BSE',
      semester: 5,
      email: 'a@x.pk',
      courseIds: courseIds,
    );

Future<_FakeRepo> _pump(WidgetTester tester, {List<StudentModel> students = const []}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      coursesProvider.overrideWith((ref) => Stream.value(_courses)),
      allStudentsProvider.overrideWith((ref) => Stream.value(students)),
    ],
    child: const MaterialApp(home: Scaffold(body: AdminCoursesScreen())),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('each course shows its name with Edit and Delete, and no schedule', (tester) async {
    await _pump(tester);

    expect(find.text('Artificial Intelligence'), findsOneWidget);
    expect(find.text('Software Engineering'), findsOneWidget);
    for (final id in ['AI', 'SE']) {
      expect(find.byKey(Key('course-edit-$id')), findsOneWidget);
      expect(find.byKey(Key('course-delete-$id')), findsOneWidget);
    }
    expect(find.textContaining('scheduled'), findsNothing); // timetables are Phase 2
    expect(find.text('Add Course'), findsOneWidget);
  });

  testWidgets('Add Course needs an ID and a name, then saves just those two', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.byKey(const Key('add-course')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Letters, numbers'), findsOneWidget);
    expect(find.textContaining('Enter the course name'), findsOneWidget);
    expect(repo.saved, isEmpty);

    await tester.enterText(find.byKey(const Key('course-id-field')), 'cn');
    await tester.enterText(find.byKey(const Key('course-name-field')), 'Computer Networks');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.saved.single.id, 'cn');
    expect(repo.saved.single.name, 'Computer Networks');
  });

  testWidgets('Edit keeps the ID fixed and saves the new name', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.byKey(const Key('course-edit-SE')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('course-id-field'))).enabled, isFalse);

    await tester.enterText(find.byKey(const Key('course-name-field')), 'Software Engineering II');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.id, 'SE');
    expect(repo.saved.single.name, 'Software Engineering II');
  });

  testWidgets('a refused save says so and keeps the dialog open', (tester) async {
    final repo = await _pump(tester);
    repo.failSaves = true;

    await tester.tap(find.byKey(const Key('add-course')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-id-field')), 'CN');
    await tester.enterText(find.byKey(const Key('course-name-field')), 'Computer Networks');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('course-save-error')), findsOneWidget);
    expect(find.text('Add Course'), findsNWidgets(2)); // the button and the dialog title
  });

  testWidgets('Delete asks first; cancelling deletes nothing, confirming deletes the course', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.byKey(const Key('course-delete-AI')));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Artificial Intelligence"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await tester.tap(find.byKey(const Key('course-delete-AI')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['AI']);
  });

  testWidgets('a course that students are registered in cannot be deleted', (tester) async {
    final repo = await _pump(tester, students: [_student(['SE'])]);

    await tester.tap(find.byKey(const Key('course-delete-SE')));
    await tester.pumpAndSettle();
    expect(find.text('Cannot delete this course'), findsOneWidget);
    expect(find.textContaining('1 student is registered'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    // a course nobody is registered in can be deleted
    await tester.tap(find.byKey(const Key('course-delete-AI')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['AI']);
  });
}
