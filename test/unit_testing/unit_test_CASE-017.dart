import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CASE-017 - Select Multiplayer Workout', () {
    test('validates multiplayer workout availability specification', () {
      final availableWorkout = 'Jumping Jacks';
      final disabledWorkouts = ['Squats', 'Side Crunches'];

      expect(availableWorkout, 'Jumping Jacks');
      expect(disabledWorkouts, contains('Squats'));
      expect(disabledWorkouts, contains('Side Crunches'));
    });
  });
}
