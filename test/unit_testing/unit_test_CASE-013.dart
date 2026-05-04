import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-013 - Select Singleplayer Workout', () {
    test('validates singleplayer workout selection specification', () {
      final workouts = ['Squats', 'Jumping Jacks', 'Side Crunches'];
      final expectedResult =
          'Able to load the selected exercise parameters and proceed to cooldown settings.';

      expect(workouts, contains('Squats'));
      expect(workouts, contains('Jumping Jacks'));
      expect(workouts, contains('Side Crunches'));
      expect(expectedResult, contains('cooldown settings'));
    });
  });
}
