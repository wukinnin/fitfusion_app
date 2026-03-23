import '../../core/enums.dart';

/// Immutable data class capturing the complete result of one game session.
/// Matches the Supabase sessions table in DATABASE.md.
class GameSession {
  final WorkoutType workoutType;
  final bool won;
  final int totalReps;
  final int totalRepsRequired;
  final double totalTimeSeconds;
  final int roundsCompleted;
  final double bestRepIntervalSeconds;
  final double avgRepIntervalSeconds;
  final int livesLost;
  final DateTime completedAt;

  const GameSession({
    required this.workoutType,
    required this.won,
    required this.totalReps,
    required this.totalRepsRequired,
    required this.totalTimeSeconds,
    required this.roundsCompleted,
    required this.bestRepIntervalSeconds,
    required this.avgRepIntervalSeconds,
    required this.livesLost,
    required this.completedAt,
  });

  @override
  String toString() {
    return 'GameSession('
        'workoutType: $workoutType, '
        'won: $won, '
        'totalReps: $totalReps/$totalRepsRequired, '
        'totalTimeSeconds: ${totalTimeSeconds.toStringAsFixed(1)}, '
        'roundsCompleted: $roundsCompleted, '
        'bestRepIntervalSeconds: ${bestRepIntervalSeconds.toStringAsFixed(2)}, '
        'avgRepIntervalSeconds: ${avgRepIntervalSeconds.toStringAsFixed(2)}, '
        'livesLost: $livesLost, '
        'completedAt: $completedAt)';
  }
}
