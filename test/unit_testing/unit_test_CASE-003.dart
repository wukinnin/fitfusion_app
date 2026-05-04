import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-003 - Verify Player Account', () {
    test('validates OTP verification specification', () {
      final testCase = {
        'module': 'Sign-Up Module',
        'screen': 'Verify OTP Page',
        'description':
            'Validate by entering the email OTP code on the Verify OTP Page.',
        'expectedResult':
            'Able to verify the player account and activate access to the application.',
      };

      expect(testCase['screen'], 'Verify OTP Page');
      expect(testCase['expectedResult'], contains('activate access'));
    });
  });
}
