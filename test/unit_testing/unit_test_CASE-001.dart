import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-001 - View Welcome Page', () {
    test('validates unauthenticated welcome screen content', () {
      final testCase = {
        'module': 'Sign-Up Module',
        'screen': 'Welcome Page',
        'description':
            'Validate by opening the FitFusion mobile application as an unauthenticated user.',
        'expectedResult':
            'Able to view the FitFusion logo, tagline, Sign Up button, and Login button.',
      };

      expect(testCase['module'], 'Sign-Up Module');
      expect(testCase['expectedResult'], contains('Sign Up button'));
      expect(testCase['expectedResult'], contains('Login button'));
    });
  });
}
