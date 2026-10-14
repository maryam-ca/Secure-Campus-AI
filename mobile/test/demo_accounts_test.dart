import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/config/demo_accounts.dart';
import 'package:securecampus/features/auth/login_screen.dart';
import 'package:securecampus/providers/auth_provider.dart';
import 'package:securecampus/services/auth_service.dart';

class _FakeAuth extends Fake implements AuthService {
  final signIns = <String>[];

  @override
  Future<User> signIn({required String email, required String password}) async {
    signIns.add('$email|$password');
    // No real Firebase user in a widget test; the login screen shows this message.
    throw const AuthFailure('fake sign-in recorded');
  }
}

const _accounts = [
  DemoAccount(role: 'student', label: 'Student 001', email: 's1@x.edu', password: 'pw-s1'),
  DemoAccount(role: 'admin', label: 'Admin', email: 'admin@x.edu', password: 'pw-admin'),
];

void main() {
  group('DemoAccounts.parse', () {
    test('reads a JSON list and drops incomplete entries', () {
      final list = DemoAccounts.parse(
          '[{"role":"admin","label":"Admin","email":"a@x","password":"p"},{"role":"x","email":"","password":""}]');
      expect(list.length, 1);
      expect(list.single.email, 'a@x');
    });

    test('empty, invalid or wrong-shaped input gives an empty list', () {
      expect(DemoAccounts.parse(''), isEmpty);
      expect(DemoAccounts.parse('not json'), isEmpty);
      expect(DemoAccounts.parse('{"a":1}'), isEmpty);
    });
  });

  testWidgets('no Demo accounts button when the list is empty', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen(demoAccounts: []))));
    await tester.pump();
    expect(find.text('Demo accounts'), findsNothing);
  });

  testWidgets('tapping a demo account signs in with it', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: LoginScreen(demoAccounts: _accounts)),
    ));
    await tester.pump();

    await tester.ensureVisible(find.text('Demo accounts'));
    await tester.tap(find.text('Demo accounts'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Listed by role order: admin first, then student.
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Student 001'), findsOneWidget);

    await tester.tap(find.text('Student 001'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(auth.signIns, ['s1@x.edu|pw-s1']);
  });
}
