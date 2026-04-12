import 'package:fitfusion/features/screens/settings/edit_profile_screen.dart';
import 'package:fitfusion/features/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-014 settings routes to linked security actions', (tester) async {
    final store = IntegrationStore();

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const SettingsScreen(),
        routes: {
          '/settings/edit-profile': (_) => const EditProfileScreen(),
          '/settings/reset-password': (_) => const TargetScreen('Reset Password'),
          '/settings/change-username': (_) => const TargetScreen('Change Username'),
          '/settings/change-email': (_) => const TargetScreen('Change Email'),
          '/settings/delete-account': (_) => const TargetScreen('Delete Account'),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    final expectations = <String, String>{
      'Reset Password': 'Reset Password',
      'Change Username': 'Change Username',
      'Change Email': 'Change Email',
      'Delete Account': 'Delete Account',
    };

    for (final entry in expectations.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
