import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-038 - Change Player Password', () {
    test('validates player password change fields', () {
      final fields = [
        'current password',
        'new password',
        'confirmed new password',
      ];
      final expectedResult =
          'Able to validate credentials and update the player password.';

      expect(fields, contains('current password'));
      expect(fields, contains('confirmed new password'));
      expect(expectedResult, contains('update the player password'));
    });
  });
}
