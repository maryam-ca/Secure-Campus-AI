import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/admin/admin_students_import_screen.dart';
import 'package:securecampus/models/course_model.dart';
import 'package:securecampus/models/student_model.dart';
import 'package:securecampus/providers/admin_providers.dart';
import 'package:securecampus/services/backend_api_service.dart';

class _FakeApi extends BackendApiService {
  final calls = <Map<String, dynamic>>[];
  Object? Function(String email)? failFor;

  @override
  Future<Map<String, dynamic>> createAccount({
    required String email,
    required String name,
    required String role,
    Map<String, dynamic>? studentFields,
    String? password,
  }) async {
    final fail = failFor?.call(email);
    if (fail != null) throw fail;
    calls.add({'email': email, 'name': name, 'role': role, 'fields': studentFields, 'password': password});
    return {'uid': 'u-$email', 'email': email, 'role': role, 'temporaryPassword': 'Tmp-$name'};
  }
}

const _existing = StudentModel(
  uid: 'old',
  registrationNumber: 'FA23-BSE-001',
  name: 'Existing',
  program: 'BSE',
  semester: 5,
  email: 'existing@x.edu',
  courseIds: [],
  irisEnrolled: false,
);

const _header = 'name,email,registration_number,program,semester,courses\n';

Future<_FakeApi> _open(WidgetTester tester, {Object? Function(String email)? failFor}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final api = _FakeApi()..failFor = failFor;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      backendApiServiceProvider.overrideWithValue(api),
      allStudentsProvider.overrideWith((ref) => Stream.value([_existing])),
      courseOptionsProvider.overrideWith((ref) async => const [CourseModel(id: 'SE', name: 'Software Engineering')]),
    ],
    child: const MaterialApp(home: AdminStudentsImportScreen()),
  ));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _paste(WidgetTester tester, String csv) async {
  await tester.enterText(find.byType(TextField), csv);
  await tester.tap(find.text('Check file'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first screen explains the columns and offers file, template and paste', (tester) async {
    await _open(tester);
    expect(find.text('Choose CSV file'), findsOneWidget);
    expect(find.text('Copy template'), findsOneWidget);
    expect(find.textContaining('registration_number'), findsWidgets);
  });

  testWidgets('empty input and a file with missing columns are refused with a clear message', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Check file'));
    await tester.pump();
    expect(find.text('Choose a CSV file or paste its contents first.'), findsOneWidget);

    await _paste(tester, 'name,email\nAyesha,a@x.edu\n');
    expect(find.textContaining('Missing a "registration_number" column'), findsOneWidget);
    expect(find.text('Choose CSV file'), findsOneWidget); // still on the first step
  });

  testWidgets('review shows the good rows and each problem by line, and only valid rows are imported', (tester) async {
    final api = await _open(tester);

    await _paste(
      tester,
      '${_header}'
      'Ayesha Khan,a@x.edu,FA24-BSE-011,BSE,3,SE\n'
      'Bad Email,not-an-email,FA24-BSE-012,BSE,1,\n'
      'Dup Reg,d@x.edu,FA23-BSE-001,BSE,1,\n',
    );

    expect(find.text('1 ready to import, 2 with problems (these will be skipped).'), findsOneWidget);
    expect(find.text('Line 3 - Bad Email'), findsOneWidget);
    expect(find.textContaining('is not a valid email'), findsOneWidget);
    expect(find.textContaining('FA23-BSE-001 already exists'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);

    await tester.tap(find.text('Import 1 student'));
    await tester.pumpAndSettle();

    expect(api.calls.length, 1);
    final call = api.calls.single;
    expect(call['email'], 'a@x.edu');
    expect(call['role'], 'student');
    expect(call['password'], isNull, reason: 'the server must generate the temporary password');
    expect(call['fields'], {'registrationNumber': 'FA24-BSE-011', 'program': 'BSE', 'semester': 3, 'courses': ['SE']});

    expect(find.text('1 account created.'), findsOneWidget);
    expect(find.text('Copy accounts and passwords'), findsOneWidget);
  });

  testWidgets('a row the server refuses is reported and the others still go through', (tester) async {
    final api = await _open(tester, failFor: (email) => email == 'b@x.edu' ? const BackendApiException('registration number already in use') : null);

    await _paste(tester, '${_header}A,a@x.edu,FA24-BSE-011,,,\nB,b@x.edu,FA24-BSE-012,,,\nC,c@x.edu,FA24-BSE-013,,,\n');
    await tester.tap(find.text('Import 3 students'));
    await tester.pumpAndSettle();

    expect(api.calls.map((c) => c['email']), ['a@x.edu', 'c@x.edu']);
    expect(find.text('2 accounts created, 1 not created.'), findsOneWidget);
    expect(find.text('B (FA24-BSE-012)'), findsOneWidget);
    expect(find.text('registration number already in use'), findsOneWidget);
  });

  testWidgets('an unreachable server stops the import and says so', (tester) async {
    final api = await _open(tester, failFor: (email) => email == 'b@x.edu' ? const SocketException('no route') : null);

    await _paste(tester, '${_header}A,a@x.edu,FA24-BSE-011,,,\nB,b@x.edu,FA24-BSE-012,,,\nC,c@x.edu,FA24-BSE-013,,,\n');
    await tester.tap(find.text('Import 3 students'));
    await tester.pumpAndSettle();

    expect(api.calls.map((c) => c['email']), ['a@x.edu']); // nothing attempted after the failure
    expect(find.text('1 account created, 2 not created.'), findsOneWidget);
    expect(find.textContaining('Could not reach the SecureCampus server'), findsOneWidget);
    expect(find.textContaining('Not attempted'), findsOneWidget);
  });

  testWidgets('Back from the review returns to editing the CSV', (tester) async {
    await _open(tester);
    await _paste(tester, '${_header}A,a@x.edu,FA24-BSE-011,,,\n');
    expect(find.text('Import 1 student'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Check file'), findsOneWidget);
  });
}
