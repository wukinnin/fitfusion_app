import 'enums.dart';

/// Emitted by RepDetector each time a complete rep is detected.
class RepEvent {
  final WorkoutType workoutType;
  final DateTime timestamp;
  const RepEvent({required this.workoutType, required this.timestamp});
}

/// Coarse jumping-jack movement phases emitted by RepDetector.
enum JumpingJackPhase { down, up }

/// Emitted when a jumping-jack detector changes phase.
class JumpingJackPhaseEvent {
  final JumpingJackPhase phase;
  final DateTime timestamp;

  const JumpingJackPhaseEvent({required this.phase, required this.timestamp});
}

/// Emitted by PaceMonitor when a rep arrives on time, or when the pace fails.
class PaceEvent {
  final PaceEventType type;

  /// Seconds elapsed between the last rep and this event.
  /// For repOnTime: the actual interval (will be < configured pace interval).
  /// For paceFailed: equals the configured pace interval exactly.
  final double intervalSeconds;

  final DateTime timestamp;

  const PaceEvent({
    required this.type,
    required this.intervalSeconds,
    required this.timestamp,
  });
}
