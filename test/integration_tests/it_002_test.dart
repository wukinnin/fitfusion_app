import 'package:fitfusion/features/screens/auth/verify_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-002 successful verification routes to login path', (tester) async {
    final store = IntegrationStore();

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        onGenerateRoute: (settings) {
          if (settings.name == '/auth/login') {
            return MaterialPageRoute<void>(
              builder: (_) => const TargetScreen('Login Target'),
            );
          }

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

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(find.text('Login Target'), findsOneWidget);
  });
}
