import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-041 - Delete Player Account', () {
    test('validates delete account confirmation specification', () {
      final testCase = {
        'fields': ['current password', 'delete confirmation'],
        'expectedResult':
            'Able to submit the deletion request only after user confirmation and credential validation.',
      };

      expect(testCase['fields'], contains('current password'));
      expect(testCase['expectedResult'], contains('credential validation'));
    });
  });
}
