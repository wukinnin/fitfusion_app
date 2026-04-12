import 'package:fitfusion/features/screens/auth/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-002 validates required sign up fields',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const SignupScreen()),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'SIGN UP'));
    await tester.pump();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
  });

  testWidgets('UT-APP-002 rejects invalid sign up inputs',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const SignupScreen()),
    );

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));

    await tester.enterText(fields.at(0), 'ab');
    await tester.enterText(fields.at(1), 'invalid-email');
    await tester.enterText(fields.at(2), 'short');
    await tester.enterText(fields.at(3), 'different');

    await tester.tap(find.widgetWithText(OutlinedButton, 'SIGN UP'));
    await tester.pump();

    expect(find.text('Username must be at least 3 characters'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Must be at least 10 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
