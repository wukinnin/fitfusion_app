import 'package:fitfusion/core/enums.dart';
import 'package:fitfusion/core/extensions.dart';
import 'package:fitfusion/features/screens/workout_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-005 selected workout starts game runtime with chosen mode',
      (tester) async {
    final store = IntegrationStore();

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const WorkoutSelectScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/game') {
            final workout = settings.arguments as WorkoutType;
            return MaterialPageRoute<void>(
              builder: (_) => TargetScreen('Game ${workout.dbKey}'),
            );
          }
          return null;
        },
      ),
    );

    await tester.tap(find.text('SQUATS'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'PLAY'));
    await tester.pumpAndSettle();

    expect(find.text('Game squats'), findsOneWidget);
  });
}
