import 'package:fitfusion/features/screens/settings/change_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-014 rejects invalid email change requests',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const ChangeEmailScreen()),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE EMAIL'));
    await tester.pump();
    expect(find.text('All fields are required'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'currentpass');
    await tester.enterText(fields.at(1), 'invalid-email');
    await tester.enterText(fields.at(2), 'invalid-email');
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE EMAIL'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.enterText(fields.at(1), 'new@example.com');
    await tester.enterText(fields.at(2), 'other@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE EMAIL'));
    await tester.pump();
    expect(find.text('Emails do not match'), findsOneWidget);
  });
}
