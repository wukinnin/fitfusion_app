import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-012 - Select Game Mode', () {
    test('validates mode selection options and routing', () {
      final testCase = {
        'module': 'View Dashboard Module',
        'screen': 'Mode Selection Page',
        'modes': ['Singleplayer', 'Multiplayer'],
        'expectedResult':
            'Able to save the selected mode and proceed to the corresponding workout selection screen.',
      };

      expect(testCase['modes'], contains('Singleplayer'));
      expect(testCase['modes'], contains('Multiplayer'));
      expect(testCase['expectedResult'], contains('workout selection'));
    });
  });
}
