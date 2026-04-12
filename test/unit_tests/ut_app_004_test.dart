import 'package:fitfusion/features/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-004 validates empty login credentials',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const LoginScreen()),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'LOGIN'));
    await tester.pump();

    expect(find.text('Email or username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('UT-APP-004 routes to forgot password and sign up flows',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const LoginScreen(),
        routes: {
          '/auth/forgot-password': (_) => const TargetScreen('Forgot Password Target'),
          '/auth/signup': (_) => const TargetScreen('Sign Up Target'),
        },
      ),
    );

    await tester.tap(find.text('FORGOT PASSWORD?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot Password Target'), findsOneWidget);

    await tester.pumpWidget(
      buildTestApp(
        home: const LoginScreen(),
        routes: {
          '/auth/forgot-password': (_) => const TargetScreen('Forgot Password Target'),
          '/auth/signup': (_) => const TargetScreen('Sign Up Target'),
        },
      ),
    );

    await tester.tap(find.text('SIGN UP'));
    await tester.pumpAndSettle();
    expect(find.text('Sign Up Target'), findsOneWidget);
  });
}
