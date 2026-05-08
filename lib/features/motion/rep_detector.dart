import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/events.dart';

class _LandmarkBuffer {
  final int windowSize;
  final Queue<double> _values = Queue<double>();

  _LandmarkBuffer(this.windowSize);

  void add(double value) {
    _values.addLast(value);
    if (_values.length > windowSize) {
      _values.removeFirst();
    }
  }

  double get average {
    if (_values.isEmpty) return 0.0;
    return _values.reduce((a, b) => a + b) / _values.length;
  }

  bool get isFull => _values.length >= windowSize;

  void clear() => _values.clear();
}

// State Machine 1 — Squats
enum _SquatState { standing, squatDown }

// State Machine 2 — Jumping Jacks
enum _JumpingJackState { armsDown, armsUp }

// State Machine 3 — Standing Oblique Side Crunches
// Left and right sides are fully independent concurrent state machines.
// A rep is emitted the moment either side completes a full crunch-and-return cycle.
enum _CrunchSideState { extended, crunching }

class RepDetector {
  final WorkoutType workoutType;
  final bool lenientJumpingJacks;

  late final StreamSubscription<Pose?> _poseSubscription;
  final StreamController<RepEvent> _repController =
      StreamController<RepEvent>.broadcast();
  final StreamController<JumpingJackPhaseEvent> _jumpingJackPhaseController =
      StreamController<JumpingJackPhaseEvent>.broadcast();

  Stream<RepEvent> get repStream => _repController.stream;
  Stream<JumpingJackPhaseEvent> get jumpingJackPhaseStream =>
      _jumpingJackPhaseController.stream;
  bool _isEnabled = false;
  bool _isDisposed = false;
  Future<void>? _disposeFuture;

  _SquatState _squatState = _SquatState.standing;
  double? _squatStandingBaseline;
  final _LandmarkBuffer _squatBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );

  _JumpingJackState _jackState = _JumpingJackState.armsDown;
  final _LandmarkBuffer _jackLeftBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );
  final _LandmarkBuffer _jackRightBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );
  final _LandmarkBuffer _jackLegSpreadBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );
  final _LandmarkBuffer _jackLegSymmetryBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );

  // Per-side independent state — left and right are never mutually exclusive
  _CrunchSideState _leftCrunchState = _CrunchSideState.extended;
  _CrunchSideState _rightCrunchState = _CrunchSideState.extended;

  // Robustness: Cache the shoulder width so momentary occlusion doesn't break detection
  double? _lastValidShoulderWidth;

  // Primary rep metric: elbow-to-knee distance, normalised by shoulder width.
  // Small value = elbow and raised knee are close together (crunched).
  final _LandmarkBuffer _crunchLeftElbowKneeBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );
  final _LandmarkBuffer _crunchRightElbowKneeBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );

  // Form validator: both elbows must stay anchored near the head/ears.
  // This is a practical pose-estimation proxy for "both hands on head".
  final _LandmarkBuffer _crunchLeftElbowEarBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );
  final _LandmarkBuffer _crunchRightElbowEarBuffer = _LandmarkBuffer(
    kLandmarkBufferWindowSize,
  );

  RepDetector({
    required this.workoutType,
    required Stream<Pose?> poseStream,
    this.lenientJumpingJacks = false,
  }) {
    _initializeStateForWorkout();
    _poseSubscription = poseStream.listen(_onPose);
  }

  double get _jumpingJackWristRaiseThreshold => lenientJumpingJacks
      ? kMultiplayerJumpingJackWristRaiseThreshold
      : kJumpingJackWristRaiseThreshold;

  double get _jumpingJackArmsDownThreshold =>
      lenientJumpingJacks ? kMultiplayerJumpingJackArmsDownThreshold : 0.0;

  double get _jumpingJackPerLegThreshold => lenientJumpingJacks
      ? kMultiplayerJumpingJackPerLegThreshold
      : kJumpingJackPerLegThreshold;

  double get _jumpingJackLegsTogetherRatio => lenientJumpingJacks
      ? kMultiplayerJumpingJackLegsTogetherRatio
      : kJumpingJackLegsTogetherRatio;

  double get _landmarkLikelihoodThreshold => lenientJumpingJacks
      ? kMultiplayerRepLandmarkLikelihoodThreshold
      : kLandmarkLikelihoodThreshold;

  void _initializeStateForWorkout() {
    reset();
  }

  void _onPose(Pose? pose) {
    if (_isDisposed) return;
    if (!_isEnabled) return;
    if (pose == null) return;

    switch (workoutType) {
      case WorkoutType.squats:
        _processSquat(pose);
        break;
      case WorkoutType.jumpingJacks:
        _processJumpingJack(pose);
        break;
      case WorkoutType.obliqueCrunches:
        _processObliqueCrunch(pose);
        break;
    }
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeInternal();
    await _disposeFuture;
  }

  Future<void> _disposeInternal() async {
    _isDisposed = true;
    _isEnabled = false;
    await _poseSubscription.cancel();
    if (!_repController.isClosed) {
      await _repController.close();
    }
    if (!_jumpingJackPhaseController.isClosed) {
      await _jumpingJackPhaseController.close();
    }
  }

  void _emitRep() {
    if (_isDisposed || _repController.isClosed) return;
    assert(() {
      debugPrint('[RepDetector] REP DETECTED — $workoutType');
      return true;
    }());
    _repController.add(
      RepEvent(workoutType: workoutType, timestamp: DateTime.now()),
    );
  }

  void _emitJumpingJackPhase(JumpingJackPhase phase) {
    if (_isDisposed || _jumpingJackPhaseController.isClosed) return;
    assert(() {
      debugPrint('[RepDetector] Jumping Jack phase: $phase');
      return true;
    }());
    _jumpingJackPhaseController.add(
      JumpingJackPhaseEvent(phase: phase, timestamp: DateTime.now()),
    );
  }

  void setEnabled(bool enabled) {
    if (_isDisposed) return;
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    reset();
  }

  void reset() {
    _squatState = _SquatState.standing;
    _squatStandingBaseline = null;
    _jackState = _JumpingJackState.armsDown;
    _leftCrunchState = _CrunchSideState.extended;
    _rightCrunchState = _CrunchSideState.extended;
    _squatBuffer.clear();
    _jackLeftBuffer.clear();
    _jackRightBuffer.clear();
    _jackLegSpreadBuffer.clear();
    _jackLegSymmetryBuffer.clear();
    _crunchLeftElbowKneeBuffer.clear();
    _crunchRightElbowKneeBuffer.clear();
    _crunchLeftElbowEarBuffer.clear();
    _crunchRightElbowEarBuffer.clear();
    _lastValidShoulderWidth = null;
    assert(() {
      debugPrint('[RepDetector] State reset');
      return true;
    }());
  }

  // --- Squat Logic ---

  void _processSquat(Pose pose) {
    // Use average of left and right sides for robustness
    // If one side is not visible, the other side still works
    final metric = _computeSquatMetric(pose);
    if (metric == null) return;

    _squatBuffer.add(metric);
    if (!_squatBuffer.isFull) return; // wait for buffer to fill before deciding

    final smoothed = _squatBuffer.average;
    _refreshSquatStandingBaseline(smoothed);

    final baseline = _squatStandingBaseline;
    if (baseline == null || baseline <= 0) return;

    final depthRatio = smoothed / baseline;

    switch (_squatState) {
      case _SquatState.standing:
        // Hip drops toward knee — delta decreases relative to the standing baseline.
        // Count once the player reaches at least a half squat (parallel-ish) or deeper.
        if (depthRatio < kSquatDownThreshold) {
          _squatState = _SquatState.squatDown;
          assert(() {
            debugPrint(
              '[RepDetector] Squat DOWN detected '
              '(ratio: ${depthRatio.toStringAsFixed(3)}, '
              'metric: ${smoothed.toStringAsFixed(3)}, '
              'baseline: ${baseline.toStringAsFixed(3)})',
            );
            return true;
          }());
        }
        break;

      case _SquatState.squatDown:
        // Hip rises back up — require a clear return toward the standing baseline.
        if (depthRatio > kSquatUpThreshold) {
          _squatState = _SquatState.standing;
          assert(() {
            debugPrint(
              '[RepDetector] Squat UP detected '
              '(ratio: ${depthRatio.toStringAsFixed(3)}, '
              'metric: ${smoothed.toStringAsFixed(3)}, '
              'baseline: ${baseline.toStringAsFixed(3)})',
            );
            return true;
          }());
          _emitRep();
        }
        break;
    }
  }

  void _refreshSquatStandingBaseline(double smoothed) {
    final baseline = _squatStandingBaseline;

    if (baseline == null) {
      _squatStandingBaseline = smoothed;
      return;
    }

    // Only update the baseline while the player is effectively upright.
    // This prevents the detector from "learning" a crouched pose as standing.
    if (_squatState == _SquatState.standing) {
      if (smoothed > baseline) {
        _squatStandingBaseline = smoothed;
        return;
      }

      if (smoothed > baseline * kSquatUpThreshold) {
        _squatStandingBaseline = baseline * 0.9 + smoothed * 0.1;
      }
    }
  }

  double? _computeSquatMetric(Pose pose) {
    // hipKneeDelta = knee.y - hip.y
    // In image space, y increases downward.
    // Standing: hip is well above knee, so knee.y > hip.y, delta is POSITIVE and large.
    // Half squat / parallel: delta shrinks noticeably compared with standing.
    // Full squat / deep: delta gets even smaller.

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    // Try to get at least one valid side
    double? leftDelta;
    double? rightDelta;

    if (leftHip != null &&
        leftKnee != null &&
        leftHip.likelihood >= _landmarkLikelihoodThreshold &&
        leftKnee.likelihood >= _landmarkLikelihoodThreshold) {
      leftDelta = leftKnee.y - leftHip.y;
    }

    if (rightHip != null &&
        rightKnee != null &&
        rightHip.likelihood >= _landmarkLikelihoodThreshold &&
        rightKnee.likelihood >= _landmarkLikelihoodThreshold) {
      rightDelta = rightKnee.y - rightHip.y;
    }

    if (leftDelta == null && rightDelta == null) return null;
    if (leftDelta == null) return rightDelta;
    if (rightDelta == null) return leftDelta;
    return (leftDelta + rightDelta) / 2.0; // average of both sides
  }

  // --- Jumping Jack Logic ---

  void _processJumpingJack(Pose pose) {
    final leftMetric = _computeJackMetric(
      pose,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftShoulder,
    );
    final rightMetric = _computeJackMetric(
      pose,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightShoulder,
    );

    // Returns [spreadRatio, symmetryRatio]
    final legMetrics = _computeJackLegMetrics(pose);

    if (leftMetric == null || rightMetric == null || legMetrics == null) return;

    _jackLeftBuffer.add(leftMetric);
    _jackRightBuffer.add(rightMetric);
    _jackLegSpreadBuffer.add(legMetrics[0]);
    _jackLegSymmetryBuffer.add(legMetrics[1]);

    if (!_jackLeftBuffer.isFull ||
        !_jackRightBuffer.isFull ||
        !_jackLegSpreadBuffer.isFull ||
        !_jackLegSymmetryBuffer.isFull) {
      return;
    }

    final leftSmoothed = _jackLeftBuffer.average;
    final rightSmoothed = _jackRightBuffer.average;
    final spreadSmoothed = _jackLegSpreadBuffer.average;
    final symmetrySmoothed = _jackLegSymmetryBuffer.average;

    // Debug print
    if (leftSmoothed > 0.05 || rightSmoothed > 0.05) {
      assert(() {
        debugPrint(
          '[JJ Debug] L:${leftSmoothed.toStringAsFixed(3)} R:${rightSmoothed.toStringAsFixed(3)} Spread:${spreadSmoothed.toStringAsFixed(2)} Sym:${symmetrySmoothed.toStringAsFixed(2)} State:$_jackState',
        );
        return true;
      }());
    }

    switch (_jackState) {
      case _JumpingJackState.armsDown:
        // Arms raise: wrist goes ABOVE shoulder
        // AND Legs must be symmetrically apart
        // symmetrySmoothed = min(distL, distR) / shoulderWidth.
        // If one leg stays in, symmetrySmoothed will be small.
        if (leftSmoothed > _jumpingJackWristRaiseThreshold &&
            rightSmoothed > _jumpingJackWristRaiseThreshold &&
            symmetrySmoothed > _jumpingJackPerLegThreshold) {
          _jackState = _JumpingJackState.armsUp;
          _emitJumpingJackPhase(JumpingJackPhase.up);
          assert(() {
            debugPrint('[RepDetector] Jumping Jack UP detected (Symmetrical)');
            return true;
          }());
        }
        break;

      case _JumpingJackState.armsUp:
        // Arms return down: wrist drops back below shoulder
        // AND Legs must be together (total spread small)
        if (leftSmoothed <= _jumpingJackArmsDownThreshold &&
            rightSmoothed <= _jumpingJackArmsDownThreshold &&
            spreadSmoothed < _jumpingJackLegsTogetherRatio) {
          _jackState = _JumpingJackState.armsDown;
          _emitJumpingJackPhase(JumpingJackPhase.down);
          _emitRep();
        }
        break;
    }
  }

  List<double>? _computeJackLegMetrics(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }

    // Check likelihoods
    if (leftShoulder.likelihood < _landmarkLikelihoodThreshold ||
        rightShoulder.likelihood < _landmarkLikelihoodThreshold ||
        leftHip.likelihood < _landmarkLikelihoodThreshold ||
        rightHip.likelihood < _landmarkLikelihoodThreshold ||
        leftAnkle.likelihood < _landmarkLikelihoodThreshold ||
        rightAnkle.likelihood < _landmarkLikelihoodThreshold) {
      return null;
    }

    final shoulderWidth = math.sqrt(
      math.pow(leftShoulder.x - rightShoulder.x, 2) +
          math.pow(leftShoulder.y - rightShoulder.y, 2),
    );

    if (shoulderWidth == 0) return null;

    // Metric 1: Total Spread (Ankle to Ankle)
    final ankleDistance = math.sqrt(
      math.pow(leftAnkle.x - rightAnkle.x, 2) +
          math.pow(leftAnkle.y - rightAnkle.y, 2),
    );
    final spreadRatio = ankleDistance / shoulderWidth;

    // Metric 2: Symmetry (Min distance from hip center)
    final midHipX = (leftHip.x + rightHip.x) / 2;
    final leftDist = (leftAnkle.x - midHipX).abs();
    final rightDist = (rightAnkle.x - midHipX).abs();

    // We care about the *minimum* extension. If one leg is 0.0 and the other is 1.0, min is 0.0 -> Fail.
    final symmetryRatio = math.min(leftDist, rightDist) / shoulderWidth;

    return [spreadRatio, symmetryRatio];
  }

  double? _computeJackMetric(
    Pose pose,
    PoseLandmarkType wristType,
    PoseLandmarkType shoulderType,
  ) {
    final wrist = pose.landmarks[wristType];
    final shoulder = pose.landmarks[shoulderType];

    if (wrist == null || shoulder == null) return null;
    if (wrist.likelihood < _landmarkLikelihoodThreshold) return null;
    if (shoulder.likelihood < _landmarkLikelihoodThreshold) return null;

    // shoulder.y - wrist.y:
    // Positive = wrist is higher than shoulder (arms raised)
    // Zero or negative = wrist at or below shoulder (arms down)
    return shoulder.y - wrist.y;
  }

  // --- Standing Oblique Side Crunch Logic ---
  //
  // Exercise form (from reference image):
  //   • Hands interlaced behind the head, elbows flared wide.
  //   • One knee drives upward and across while the torso crunches
  //     laterally, bringing the same-side elbow down to meet the knee.
  //   • Return to standing upright to complete one rep.
  //
  // Detection strategy:
  //   1. PRIMARY METRIC  — elbow↔knee distance (normalised by shoulder width).
  //      Standing/extended: large ratio (elbow is far above the lowered knee).
  //      Crunched:          small ratio (elbow and raised knee converge).
  //   2. FORM VALIDATOR  — ear↔elbow distance on BOTH sides.
  //      This acts as a head-anchor proxy so reps only count while the player
  //      keeps both hands/elbows in a hands-on-head posture.
  //      If either elbow leaves the head position, the crunch state machine is
  //      re-armed and no rep can complete until proper form is restored.
  //
  // Left and right sides run as fully independent state machines so that
  // alternating reps (L, R, L, R …) are each counted without one side
  // blocking the other.

  void _processObliqueCrunch(Pose pose) {
    // Compute a normalisation reference that is robust to camera distance.
    final currentWidth = _computeShoulderWidth(pose);

    if (currentWidth != null && currentWidth > 0) {
      _lastValidShoulderWidth = currentWidth;
    }

    final refWidth = _lastValidShoulderWidth;
    if (refWidth == null) return; // No reference yet, cannot normalize

    // --- Enforce "both hands on head" before accepting any crunch motion ---
    final leftElbowEar = _computeNormalisedDistance(
      pose,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftEar,
      refWidth,
    );
    final rightElbowEar = _computeNormalisedDistance(
      pose,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightEar,
      refWidth,
    );

    if (leftElbowEar == null || rightElbowEar == null) {
      _invalidateObliqueCrunchTracking();
      return;
    }

    _crunchLeftElbowEarBuffer.add(leftElbowEar);
    _crunchRightElbowEarBuffer.add(rightElbowEar);

    if (!_crunchLeftElbowEarBuffer.isFull ||
        !_crunchRightElbowEarBuffer.isFull) {
      return;
    }

    final leftElbowEarSmoothed = _crunchLeftElbowEarBuffer.average;
    final rightElbowEarSmoothed = _crunchRightElbowEarBuffer.average;
    final hasHandsOnHeadForm =
        leftElbowEarSmoothed <= kCrunchElbowEarOnHeadThreshold &&
        rightElbowEarSmoothed <= kCrunchElbowEarOnHeadThreshold;

    if (!hasHandsOnHeadForm) {
      assert(() {
        debugPrint(
          '[Crunch Form] Invalid hands-on-head form '
          '(leftElbowEar: ${leftElbowEarSmoothed.toStringAsFixed(3)}, '
          'rightElbowEar: ${rightElbowEarSmoothed.toStringAsFixed(3)})',
        );
        return true;
      }());
      _invalidateObliqueCrunchTracking();
      return;
    }

    // --- Gather per-side raw rep metrics ---
    final leftElbowKnee = _computeNormalisedDistance(
      pose,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftKnee,
      refWidth,
    );
    final rightElbowKnee = _computeNormalisedDistance(
      pose,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightKnee,
      refWidth,
    );

    // Only add to a buffer when its landmarks are visible this frame.
    // Buffers are updated atomically per side so they stay in sync.
    if (leftElbowKnee != null) {
      _crunchLeftElbowKneeBuffer.add(leftElbowKnee);
    }
    if (rightElbowKnee != null) {
      _crunchRightElbowKneeBuffer.add(rightElbowKnee);
    }

    // Process each side independently once its buffers are warm.
    if (_crunchLeftElbowKneeBuffer.isFull) {
      _evaluateCrunchSide(
        side: 'LEFT',
        elbowKneeSmoothed: _crunchLeftElbowKneeBuffer.average,
        stateGetter: () => _leftCrunchState,
        stateSetter: (s) => _leftCrunchState = s,
      );
    }

    if (_crunchRightElbowKneeBuffer.isFull) {
      _evaluateCrunchSide(
        side: 'RIGHT',
        elbowKneeSmoothed: _crunchRightElbowKneeBuffer.average,
        stateGetter: () => _rightCrunchState,
        stateSetter: (s) => _rightCrunchState = s,
      );
    }
  }

  void _invalidateObliqueCrunchTracking() {
    // If form breaks, the player must re-establish a clean starting posture
    // before another rep can begin or complete.
    _crunchLeftElbowKneeBuffer.clear();
    _crunchRightElbowKneeBuffer.clear();
    _leftCrunchState = _CrunchSideState.extended;
    _rightCrunchState = _CrunchSideState.extended;
  }

  void _evaluateCrunchSide({
    required String side,
    required double elbowKneeSmoothed,
    required _CrunchSideState Function() stateGetter,
    required void Function(_CrunchSideState) stateSetter,
  }) {
    final currentState = stateGetter();

    switch (currentState) {
      case _CrunchSideState.extended:
        // Elbow and knee converge — crunch phase begins.
        if (elbowKneeSmoothed < kCrunchElbowKneeCrunchThreshold) {
          stateSetter(_CrunchSideState.crunching);
          assert(() {
            debugPrint(
              '[Crunch $side] CRUNCHING '
              '(elbowKnee: ${elbowKneeSmoothed.toStringAsFixed(3)})',
            );
            return true;
          }());
        }
        break;

      case _CrunchSideState.crunching:
        // Elbow and knee separate back to standing position — rep complete.
        // The extended threshold is intentionally larger than the crunch threshold
        // (hysteresis) to prevent oscillation at the boundary.
        if (elbowKneeSmoothed > kCrunchElbowKneeExtendedThreshold) {
          stateSetter(_CrunchSideState.extended);
          _emitRep();
          assert(() {
            debugPrint(
              '[Crunch $side] REP COMPLETE '
              '(elbowKnee: ${elbowKneeSmoothed.toStringAsFixed(3)})',
            );
            return true;
          }());
        }
        break;
    }
  }

  /// Returns the Euclidean distance between two landmarks, divided by
  /// [refWidth] to make it invariant to camera distance and body size.
  double? _computeNormalisedDistance(
    Pose pose,
    PoseLandmarkType typeA,
    PoseLandmarkType typeB,
    double refWidth,
  ) {
    final a = pose.landmarks[typeA];
    final b = pose.landmarks[typeB];

    if (a == null || b == null) return null;
    if (a.likelihood < _landmarkLikelihoodThreshold) return null;
    if (b.likelihood < _landmarkLikelihoodThreshold) return null;

    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy) / refWidth;
  }

  /// Returns the Euclidean distance between the two shoulders, used as a
  /// body-relative normalisation reference throughout the crunch detector.
  double? _computeShoulderWidth(Pose pose) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (ls == null || rs == null) return null;
    if (ls.likelihood < _landmarkLikelihoodThreshold) return null;
    if (rs.likelihood < _landmarkLikelihoodThreshold) return null;

    final dx = ls.x - rs.x;
    final dy = ls.y - rs.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
