import 'package:fitfusion/features/screens/settings/reset_password_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-012 blocks invalid in-session password updates',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const ResetPasswordSettingsScreen()),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE PASSWORD'));
    await tester.pump();
    expect(find.text('All fields are required'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'currentpass');
    await tester.enterText(fields.at(1), 'short');
    await tester.enterText(fields.at(2), 'short');
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE PASSWORD'));
    await tester.pump();
    expect(find.text('New password must be at least 10 characters'), findsOneWidget);

    await tester.enterText(fields.at(1), 'newpassword1');
    await tester.enterText(fields.at(2), 'newpassword2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE PASSWORD'));
    await tester.pump();
    expect(find.text('New passwords do not match'), findsOneWidget);
  });
}
