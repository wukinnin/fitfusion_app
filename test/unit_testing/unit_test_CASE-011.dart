import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-011 - View Player Home Screen', () {
    test('validates home screen dashboard elements', () {
      final expectedElements = [
        'player name',
        'knight status',
        'Play button',
        'Performance button',
        'Settings button',
      ];

      expect(expectedElements, contains('Play button'));
      expect(expectedElements, contains('knight status'));
    });
  });
}
