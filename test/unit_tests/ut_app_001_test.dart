import 'package:fitfusion/features/screens/auth/auth_landing_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('UT-APP-001 validates Sign Up and Login navigation from welcome page',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const AuthLandingScreen(),
        routes: {
          '/auth/signup': (_) => const TargetScreen('Sign Up Target'),
          '/auth/login': (_) => const TargetScreen('Login Target'),
        },
      ),
    );

    expect(find.text('SIGN UP'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);

    await tester.tap(find.text('SIGN UP'));
    await tester.pumpAndSettle();
    expect(find.text('Sign Up Target'), findsOneWidget);

    await tester.pumpWidget(
      buildTestApp(
        home: const AuthLandingScreen(),
        routes: {
          '/auth/signup': (_) => const TargetScreen('Sign Up Target'),
          '/auth/login': (_) => const TargetScreen('Login Target'),
        },
      ),
    );

    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();
    expect(find.text('Login Target'), findsOneWidget);
  });
}
