import 'package:fitfusion/features/game/game_session.dart';
import 'package:fitfusion/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _SessionSaveHarness extends StatelessWidget {
  final GameSession session;

  const _SessionSaveHarness({required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await AppServicesScope.of(context).sessionService.saveSession(session);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved')),
              );
            }
          },
          child: const Text('COMPLETE SESSION'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('IT-006 completed session writes metrics to persistence service',
      (tester) async {
    final store = IntegrationStore();
    final services = makeFakeServices(store: store);

    await tester.pumpWidget(
      buildIntegrationApp(
        services: services,
        home: _SessionSaveHarness(session: sampleSession()),
      ),
    );

    await tester.tap(find.text('COMPLETE SESSION'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(store.sessions, hasLength(1));
    expect(store.sessions.single.totalReps, 20);
  });
}
