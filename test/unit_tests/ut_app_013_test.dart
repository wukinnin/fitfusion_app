import 'package:fitfusion/features/screens/settings/change_username_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-013 rejects invalid username change inputs',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(home: const ChangeUsernameScreen()),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE USERNAME'));
    await tester.pump();
    expect(find.text('All fields are required'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'currentpass');
    await tester.enterText(fields.at(1), 'ab');
    await tester.enterText(fields.at(2), 'ab');
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE USERNAME'));
    await tester.pump();
    expect(find.text('Username must be at least 3 characters'), findsOneWidget);

    await tester.enterText(fields.at(1), 'newusername');
    await tester.enterText(fields.at(2), 'otherusername');
    await tester.tap(find.widgetWithText(ElevatedButton, 'CHANGE USERNAME'));
    await tester.pump();
    expect(find.text('Usernames do not match'), findsOneWidget);
  });
}
