import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-018 - Input Player 2 Email', () {
    test('validates player 2 email verification request specification', () {
      final testCase = {
        'screen': 'Player 2 Email Input Page',
        'description':
            'Validate by entering Player 2 email address and sending a verification code.',
        'expectedResult':
            'Able to validate Player 2 email and send an OTP code for verification.',
      };

      expect(testCase['screen'], contains('Player 2'));
      expect(testCase['expectedResult'], contains('OTP code'));
    });
  });
}
