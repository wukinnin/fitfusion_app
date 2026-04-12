import 'package:fitfusion/features/screens/settings/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-015 validates delete-account cancellation and password requirement',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              );
            },
            child: const Text('Open Delete Screen'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Delete Screen'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'DELETE'));
    await tester.pump();
    expect(find.text('Current password is required'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('Open Delete Screen'), findsOneWidget);
  });
}
