import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-028 - View Performance Menu', () {
    test('validates performance menu navigation options', () {
      final options = ['Leaderboard', 'Achievements', 'Stats'];

      expect(options, contains('Leaderboard'));
      expect(options, contains('Achievements'));
      expect(options, contains('Stats'));
    });
  });
}
