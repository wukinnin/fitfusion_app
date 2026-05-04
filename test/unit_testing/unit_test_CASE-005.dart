import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-005 - Request Player Password Reset', () {
    test('validates player password reset request specification', () {
      final testCase = {
        'module': 'Login Module',
        'screen': 'Forgot Password Page',
        'description':
            'Validate by entering a registered email address on the mobile Forgot Password Page.',
        'expectedResult':
            'Able to send a reset or verification code to the registered email address.',
      };

      expect(testCase['screen'], 'Forgot Password Page');
      expect(testCase['expectedResult'], contains('registered email address'));
    });
  });
}
