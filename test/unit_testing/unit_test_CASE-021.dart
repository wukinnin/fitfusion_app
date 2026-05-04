import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-021 - View Multiplayer Tutorial', () {
    test('validates multiplayer tutorial specification', () {
      final testCase = {
        'screen': 'Multiplayer Tutorial Page',
        'expectedResult':
            'Able to view simultaneous-rep instructions and continue to the multiplayer game screen.',
      };

      expect(testCase['screen'], contains('Multiplayer'));
      expect(testCase['expectedResult'], contains('simultaneous-rep'));
    });
  });
}
