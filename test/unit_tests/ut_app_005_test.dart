import 'package:fitfusion/features/screens/auth/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-005 validates recovery email format',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const ForgotPasswordScreen()),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'SEND CODE'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'invalid-email');
    await tester.tap(find.widgetWithText(OutlinedButton, 'SEND CODE'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('UT-APP-005 allows returning back to login',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BACK TO LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
  });
}
