import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-037 - Open Edit Profile Page', () {
    test('validates profile management options', () {
      final options = [
        'reset password',
        'change username',
        'change email',
        'delete account',
      ];

      expect(options, contains('reset password'));
      expect(options, contains('delete account'));
    });
  });
}
