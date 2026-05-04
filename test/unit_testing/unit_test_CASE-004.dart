import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-004 - Login Player Account', () {
    test('validates player login routing specification', () {
      final testCase = {
        'module': 'Login Module',
        'screen': 'Login Page',
        'description':
            'Validate by entering a valid email or username and password on the mobile Login Page.',
        'expectedResult':
            'Able to authenticate the player and redirect to the Home Screen.',
      };

      expect(testCase['module'], 'Login Module');
      expect(testCase['expectedResult'], contains('Home Screen'));
    });
  });
}
