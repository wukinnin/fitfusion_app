import 'package:fitfusion/features/screens/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-007 persisted session metrics are reflected in stats',
      (tester) async {
    final store = IntegrationStore()..sessions.add(sampleSession());

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const StatsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01:15.50'), findsOneWidget);
    expect(find.text('20'), findsAtLeastNWidgets(2));
    expect(find.text('10'), findsAtLeastNWidgets(2));
  });
}
