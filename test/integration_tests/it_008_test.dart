import 'package:fitfusion/features/screens/achievements_screen.dart';
import 'package:fitfusion/features/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-008 completed sessions update achievements and leaderboards',
      (tester) async {
    final store = IntegrationStore()..sessions.add(sampleSession());

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const AchievementsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First Blood'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const LeaderboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TestUser'), findsWidgets);
    expect(find.text('01:15.50'), findsWidgets);
  });
}
