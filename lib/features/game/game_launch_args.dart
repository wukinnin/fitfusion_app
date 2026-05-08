import '../../core/enums.dart';

class GameLaunchArgs {
  final WorkoutType workoutType;
  final int cooldownSeconds;
  final bool isMultiplayer;
  final String? player2UserId;
  final String? player2Email;
  final bool bonusRoundsEnabled;
  final bool bonusOnlyTestMode;

  const GameLaunchArgs({
    required this.workoutType,
    required this.cooldownSeconds,
    this.isMultiplayer = false,
    this.player2UserId,
    this.player2Email,
    this.bonusRoundsEnabled = false,
    this.bonusOnlyTestMode = false,
  });

  GameLaunchArgs copyWith({
    WorkoutType? workoutType,
    int? cooldownSeconds,
    bool? isMultiplayer,
    String? player2UserId,
    String? player2Email,
    bool? bonusRoundsEnabled,
    bool? bonusOnlyTestMode,
  }) {
    return GameLaunchArgs(
      workoutType: workoutType ?? this.workoutType,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      isMultiplayer: isMultiplayer ?? this.isMultiplayer,
      player2UserId: player2UserId ?? this.player2UserId,
      player2Email: player2Email ?? this.player2Email,
      bonusRoundsEnabled: bonusRoundsEnabled ?? this.bonusRoundsEnabled,
      bonusOnlyTestMode: bonusOnlyTestMode ?? this.bonusOnlyTestMode,
    );
  }
}
