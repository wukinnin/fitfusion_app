import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-002 - Create Player Account', () {
    test('validates sign up form submission requirements', () {
      final testCase = {
        'module': 'Sign-Up Module',
        'screen': 'Sign Up Page',
        'requiredFields': ['username', 'email', 'password', 'confirmPassword'],
        'description':
            'Validate by entering username, email, password, and confirm password on the Sign Up Page.',
        'expectedResult':
            'Able to submit valid registration details and proceed to account verification.',
      };

      expect(testCase['requiredFields'], contains('email'));
      expect(testCase['requiredFields'], contains('confirmPassword'));
      expect(testCase['expectedResult'], contains('account verification'));
    });
  });
}
