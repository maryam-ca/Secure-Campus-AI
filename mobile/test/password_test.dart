import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:securecampus/core/constants/roles.dart';
import 'package:securecampus/core/router/password_gate.dart';
import 'package:securecampus/core/utils/password_policy.dart';
import 'package:securecampus/features/auth/change_password_screen.dart';
import 'package:securecampus/models/app_user.dart';
import 'package:securecampus/providers/auth_provider.dart';
import 'package:securecampus/services/auth_service.dart';

String? _check(String pw, {String? confirm, String? current = 'Temp-9xQ2', String? reg, String? email}) =>
    validateNewPassword(newPassword: pw, confirm: confirm ?? pw, current: current, registrationNumber: reg, email: email);

AppUser _user({bool mustReset = false, UserRole role = UserRole.student}) => AppUser(
      uid: 'u1',
      email: 'fa23-bse-007@securecampus.edu.pk',
      name: 'Mehak',
      role: role,
      active: true,
      mustResetPassword: mustReset,
    );

void main() {
  group('validateNewPassword', () {
    test('accepts a good password', () {
      expect(_check('Blue-Falcon-42'), isNull);
    });

    test('too short, or missing a letter or a number', () {
      expect(_check('Ab1'), contains('8 characters'));
      expect(_check('abcdefghij'), contains('letter and one number'));
      expect(_check('12345678'), contains('letter and one number'));
    });

    test('must differ from the current password and match the confirmation', () {
      expect(_check('Temp-9xQ2abc', current: 'Temp-9xQ2abc'), contains('different'));
      expect(_check('Blue-Falcon-42', confirm: 'Blue-Falcon-43'), contains('do not match'));
    });

    test('rejects the registration number and the email name, in any format', () {
      expect(_check('FA23-BSE-007', reg: 'FA23-BSE-007'), contains('registration number'));
      expect(_check('fa23bse007', reg: 'FA23-BSE-007'), contains('registration number'));
      expect(_check('mehak.khan1', email: 'mehak.khan1@securecampus.edu.pk'), contains('registration number or email'));
      // a password that merely contains it is fine
      expect(_check('FA23-BSE-007-Rocks!', reg: 'FA23-BSE-007'), isNull);
    });
  });

  group('passwordGateRedirect', () {
    String? gate(AppUser u, String loc, {bool enforced = true, bool changed = false}) =>
        passwordGateRedirect(user: u, location: loc, enforced: enforced, changedThisSession: changed);

    test('an account with a temporary password is sent to the change screen from anywhere', () {
      expect(gate(_user(mustReset: true), '/student'), '/change-password');
      expect(gate(_user(mustReset: true, role: UserRole.admin), '/admin'), '/change-password');
    });

    test('and is left alone once it is on that screen', () {
      expect(gate(_user(mustReset: true), '/change-password'), isNull);
    });

    test('a normal account is never forced', () {
      expect(gate(_user(), '/student'), isNull);
    });

    test('not forced after changing it this session, or in a debug demo build', () {
      expect(gate(_user(mustReset: true), '/student', changed: true), isNull);
      expect(gate(_user(mustReset: true), '/student', enforced: false), isNull);
    });
  });

  group('ChangePasswordScreen', () {
    Future<_FakeAuth> pump(WidgetTester tester, AppUser user) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          currentAppUserProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: const MaterialApp(home: ChangePasswordScreen()),
      ));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('first login: explains it, has no back button, offers sign out', (tester) async {
      await pump(tester, _user(mustReset: true));

      expect(find.text('Choose your password'), findsOneWidget);
      expect(find.textContaining('temporary password'), findsWidgets);
      expect(find.text('Temporary password'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('voluntary change: normal title and field label', (tester) async {
      await pump(tester, _user());

      expect(find.text('Change password'), findsWidgets);
      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('a weak password is refused with a reason and never sent to Firebase', (tester) async {
      final auth = await pump(tester, _user());

      await tester.enterText(find.widgetWithText(TextField, 'Current password'), 'Old-pass-1');
      await tester.enterText(find.widgetWithText(TextField, 'New password'), 'short');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'short');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Change password'));
      await tester.pump();

      expect(find.textContaining('at least 8 characters'), findsWidgets);
      expect(auth.calls, isEmpty);
    });

    testWidgets('a good password goes to Firebase with the current and new values', (tester) async {
      final auth = await pump(tester, _user());

      await tester.enterText(find.widgetWithText(TextField, 'Current password'), 'Old-pass-1');
      await tester.enterText(find.widgetWithText(TextField, 'New password'), 'Blue-Falcon-42');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'Blue-Falcon-42');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Change password'));
      await tester.pump();

      expect(auth.calls, ['Old-pass-1 -> Blue-Falcon-42']);
    });

    testWidgets('a wrong current password shows the friendly message', (tester) async {
      final auth = await pump(tester, _user());
      auth.failWith = const AuthFailure('The current password is not correct.');

      await tester.enterText(find.widgetWithText(TextField, 'Current password'), 'nope-nope-1');
      await tester.enterText(find.widgetWithText(TextField, 'New password'), 'Blue-Falcon-42');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'Blue-Falcon-42');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Change password'));
      await tester.pump();
      await tester.pump();

      expect(find.text('The current password is not correct.'), findsOneWidget);
    });
  });
}

class _FakeAuth extends Fake implements AuthService {
  final calls = <String>[];
  AuthFailure? failWith;

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    if (failWith != null) throw failWith!;
    calls.add('$currentPassword -> $newPassword');
  }

  @override
  Future<void> signOut() async {}

  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}
