import 'dart:ui';

enum DetectedAction {
  none,
  squatting,
  jumpingJack,
  sideCrunch,
}

class MotionState {
  final DetectedAction action;
  final Offset bodyCenter;
  final double confidence;
  final bool leftArmRaised;
  final bool rightArmRaised;
  final bool isSquatting;
  final bool isJumping;
  final DateTime timestamp;
  final bool isStale;

  const MotionState({
    required this.action,
    required this.bodyCenter,
    required this.confidence,
    required this.leftArmRaised,
    required this.rightArmRaised,
    required this.isSquatting,
    required this.isJumping,
    required this.timestamp,
    this.isStale = false,
  });

  factory MotionState.empty() {
    return MotionState(
      action: DetectedAction.none,
      bodyCenter: Offset.zero,
      confidence: 0,
      leftArmRaised: false,
      rightArmRaised: false,
      isSquatting: false,
      isJumping: false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      isStale: true,
    );
  }

  MotionState asStale(DateTime timestamp) {
    return MotionState(
      action: action,
      bodyCenter: bodyCenter,
      confidence: confidence,
      leftArmRaised: leftArmRaised,
      rightArmRaised: rightArmRaised,
      isSquatting: isSquatting,
      isJumping: isJumping,
      timestamp: timestamp,
      isStale: true,
    );
  }
}
