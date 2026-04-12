import 'package:fitfusion/features/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-003 successful login routes to home screen', (tester) async {
    final store = IntegrationStore();

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const LoginScreen(),
        routes: {
          '/home': (_) => const TargetScreen('Home Target'),
        },
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'fitfusion@example.com');
    await tester.enterText(fields.at(1), 'strongpassword');

    await tester.tap(find.widgetWithText(OutlinedButton, 'LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('Home Target'), findsOneWidget);
  });
}
