import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/features/auth/login_screen.dart';

Widget _app() => const ProviderScope(child: MaterialApp(home: LoginScreen()));

void main() {
  testWidgets('login screen renders email, password and a Sign in button', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('submitting an empty form does not call Firebase', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // No Firebase instance exists in this test; reaching the sign-in call
    // would have thrown. Validation must stop the submit first.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
