import 'package:fitfusion/features/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-006 validates main home menu routing',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const HomeScreen(),
        routes: {
          '/select': (_) => const TargetScreen('Select Workout Target'),
          '/leaderboard': (_) => const TargetScreen('Leaderboard Target'),
          '/achievements': (_) => const TargetScreen('Achievements Target'),
          '/stats': (_) => const TargetScreen('Stats Target'),
          '/settings': (_) => const TargetScreen('Settings Target'),
        },
      ),
    );

    final expectations = <String, String>{
      'PLAY': 'Select Workout Target',
      'LEADERBOARD': 'Leaderboard Target',
      'ACHIEVEMENTS': 'Achievements Target',
      'STATS': 'Stats Target',
      'SETTINGS': 'Settings Target',
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
