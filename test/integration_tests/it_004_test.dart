import 'package:fitfusion/features/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('IT-004 play action routes from home to workout selection', (tester) async {
    final store = IntegrationStore();

    await tester.pumpWidget(
      buildIntegrationApp(
        services: makeFakeServices(store: store),
        home: const HomeScreen(),
        routes: {
          '/select': (_) => const TargetScreen('Workout Select Target'),
        },
      ),
    );

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.text('Workout Select Target'), findsOneWidget);
  });
}
