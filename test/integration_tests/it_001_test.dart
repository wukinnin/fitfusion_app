import 'package:fitfusion/features/screens/auth/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-001 signup routes to verify screen with entered email', (tester) async {
    final store = IntegrationStore();

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const SignupScreen(),
        routes: {
          '/auth/verify': (_) => const RoutedArgsScreen(),
        },
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'fitfusionuser');
    await tester.enterText(fields.at(1), 'fitfusion@example.com');
    await tester.enterText(fields.at(2), 'strongpassword');
    await tester.enterText(fields.at(3), 'strongpassword');

    await tester.tap(find.widgetWithText(OutlinedButton, 'SIGN UP'));
    await tester.pumpAndSettle();

    expect(find.text("{email: fitfusion@example.com, type: signup}"), findsOneWidget);
  });
}
