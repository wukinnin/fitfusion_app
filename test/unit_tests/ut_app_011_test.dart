import 'package:fitfusion/features/screens/settings/edit_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-011 validates navigation to account security actions',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const EditProfileScreen(),
        routes: {
          '/settings/reset-password': (_) =>
              const TargetScreen('Reset Password Target'),
          '/settings/change-username': (_) =>
              const TargetScreen('Change Username Target'),
          '/settings/change-email': (_) =>
              const TargetScreen('Change Email Target'),
          '/settings/delete-account': (_) =>
              const TargetScreen('Delete Account Target'),
        },
      ),
    );

    final expectations = <String, String>{
      'Reset Password': 'Reset Password Target',
      'Change Username': 'Change Username Target',
      'Change Email': 'Change Email Target',
      'Delete Account': 'Delete Account Target',
    };

    for (final entry in expectations.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
