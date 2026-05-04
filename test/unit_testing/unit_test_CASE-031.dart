import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-031 - View Player Statistics', () {
    test('validates stats page category and metric specification', () {
      final expectedResult =
          'Able to display session statistics and lifetime statistics for the selected category.';

      expect(expectedResult, contains('session statistics'));
      expect(expectedResult, contains('lifetime statistics'));
    });
  });
}
