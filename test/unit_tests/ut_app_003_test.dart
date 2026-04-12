import 'package:fitfusion/features/screens/auth/verify_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-003 validates OTP length before verification request',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: RouteSettings(
              name: settings.name,
              arguments: const {'email': 'fitfusion@example.com', 'type': 'signup'},
            ),
            builder: (_) => const VerifyEmailScreen(),
          );
        },
        initialRoute: '/',
      ),
    );

    expect(find.textContaining('Code sent to'), findsOneWidget);
    expect(find.text('RESEND CODE'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.widgetWithText(OutlinedButton, 'VERIFY'));
    await tester.pump();

    expect(find.text('Please enter at least 6 digits'), findsOneWidget);
  });
}
