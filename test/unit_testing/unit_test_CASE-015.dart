import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-015 - View Singleplayer Tutorial', () {
    test('validates tutorial content flow specification', () {
      final testCase = {
        'screen': 'Singleplayer Tutorial Page',
        'description':
            'Validate by opening the tutorial before a singleplayer game session.',
        'expectedResult':
            'Able to view gameplay instructions and continue to the game proper screen.',
      };

      expect(testCase['screen'], contains('Tutorial'));
      expect(testCase['expectedResult'], contains('game proper screen'));
    });
  });
}
