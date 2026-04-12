import 'package:fitfusion/features/screens/auth/login_screen.dart';
import 'package:fitfusion/features/screens/auth/verify_email_screen.dart';
import 'package:fitfusion/features/screens/settings/change_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-020 change-email flow integrates with verify and login',
      (tester) async {
    final store = IntegrationStore();
    final authService = FakeAuthService(changeEmailNeedsVerification: true);

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store, authService: authService),
        home: const ChangeEmailScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/auth/verify') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const VerifyEmailScreen(),
            );
          }
          if (settings.name == '/auth/login') {
            return MaterialPageRoute<void>(
              builder: (_) => const LoginScreen(),
            );
          }
          return null;
        },
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'currentpassword');
    await tester.enterText(fields.at(1), 'updated@example.com');
    await tester.enterText(fields.at(2), 'updated@example.com');

    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE EMAIL'));
    await tester.pumpAndSettle();

    expect(find.textContaining('updated@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
