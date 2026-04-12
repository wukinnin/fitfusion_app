import 'package:fitfusion/features/screens/workout_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-007 validates workout selection handoff to gameplay',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const WorkoutSelectScreen(),
        routes: {
          '/game': (_) => const TargetScreen('Game Target'),
        },
      ),
    );

    await tester.tap(find.text('SQUATS'));
    await tester.pumpAndSettle();

    expect(find.text('HOW TO PLAY'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'PLAY'));
    await tester.pumpAndSettle();

    expect(find.text('Game Target'), findsOneWidget);
  });
}
