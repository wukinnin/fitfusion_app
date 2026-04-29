import '../../core/enums.dart';

class GameLaunchArgs {
  final WorkoutType workoutType;
  final int cooldownSeconds;
  final bool isMultiplayer;
  final String? player2UserId;
  final String? player2Email;

  const GameLaunchArgs({
    required this.workoutType,
    required this.cooldownSeconds,
    this.isMultiplayer = false,
    this.player2UserId,
    this.player2Email,
  });
}
