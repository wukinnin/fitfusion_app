import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/constants.dart';
import 'camera_display.dart';
import 'pose_detector_service.dart';

class _PoseCandidate {
  final Pose pose;
  final Offset center;
  final Rect torsoBounds;
  final double bodySize;
  final double reliability;

  const _PoseCandidate({
    required this.pose,
    required this.center,
    required this.torsoBounds,
    required this.bodySize,
    required this.reliability,
  });

  double get centerX => center.dx;
}

enum _TrackPhase { searching, locked }

enum _PlayerLane { left, right }

class _TrackedPlayer {
  final _PlayerLane lane;
  _PoseCandidate? _candidate;
  DateTime? _lastFreshAt;

  _TrackedPlayer(this.lane);

  _PoseCandidate? get candidate => _candidate;

  void updateFresh(_PoseCandidate candidate, DateTime now) {
    _candidate = candidate;
    _lastFreshAt = now;
  }

  void clear() {
    _candidate = null;
    _lastFreshAt = null;
  }

  bool hasFreshPose(DateTime now, Duration timeout) {
    final lastFreshAt = _lastFreshAt;
    return lastFreshAt != null && now.difference(lastFreshAt) <= timeout;
  }

  bool hasVisualPose(DateTime now, Duration timeout) {
    return _candidate != null && hasFreshPose(now, timeout);
  }

  bool isMissingTooLong(DateTime now, Duration timeout) {
    final lastFreshAt = _lastFreshAt;
    return lastFreshAt == null || now.difference(lastFreshAt) > timeout;
  }
}

class _TrackingAssignment {
  final _PoseCandidate? player1Fresh;
  final _PoseCandidate? player2Fresh;
  final _PoseCandidate? player1Visual;
  final _PoseCandidate? player2Visual;
  final bool player1Detected;
  final bool player2Detected;
  final String debugLabel;

  const _TrackingAssignment({
    required this.player1Fresh,
    required this.player2Fresh,
    required this.player1Visual,
    required this.player2Visual,
    required this.player1Detected,
    required this.player2Detected,
    required this.debugLabel,
  });
}

class MediaPipeMultiplayerPoseService {
  static const MethodChannel _channel = MethodChannel(
    'fitfusion/mediapipe_pose',
  );
  static const int _initialLockStableFrames = 3;
  static const Duration _freshPoseTimeout = Duration(milliseconds: 180);
  static const Duration _visualPoseHoldTimeout = Duration(milliseconds: 450);
  static const Duration _fullResetTimeout = Duration(milliseconds: 1800);
  static const double _leftLaneMaxX = 0.49;
  static const double _rightLaneMinX = 0.51;
  static const double _initialLockMinSeparation = 0.16;
  static const double _maxFreshMatchDistance = 0.23;
  static const double _maxReacquireMatchDistance = 0.34;

  StreamSubscription? _subscription;
  final StreamController<Pose?> _player1PoseController =
      StreamController<Pose?>.broadcast();
  final StreamController<Pose?> _player2PoseController =
      StreamController<Pose?>.broadcast();
  final StreamController<bool> _player1BodyDetectedController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _player2BodyDetectedController =
      StreamController<bool>.broadcast();
  final StreamController<MultiplayerPoses> _multiplayerPoseController =
      StreamController<MultiplayerPoses>.broadcast();
  final StreamController<MultiplayerPoses> _visualMultiplayerPoseController =
      StreamController<MultiplayerPoses>.broadcast();
  final Duration _minProcessInterval = const Duration(
    milliseconds: 1000 ~/ kPoseDetectionTargetFps,
  );
  final _player1Track = _TrackedPlayer(_PlayerLane.left);
  final _player2Track = _TrackedPlayer(_PlayerLane.right);

  bool _isProcessing = false;
  bool _isEnabled = false;
  bool _isDisposed = false;
  _TrackPhase _trackPhase = _TrackPhase.searching;
  int _stableInitialLockFrames = 0;
  DateTime? _lastProcessStartedAt;
  DateTime? _lastDebugLogAt;
  int _busyFrameDrops = 0;
  int _throttledFrameDrops = 0;
  int _processedFrameCount = 0;
  int _nativeErrorCount = 0;
  int _lastNativeLatencyMs = 0;
  Future<void>? _disposeFuture;
  CameraDisplayMode _displayMode = CameraDisplayMode.portrait;

  Stream<Pose?> get player1PoseStream => _player1PoseController.stream;
  Stream<Pose?> get player2PoseStream => _player2PoseController.stream;
  Stream<bool> get player1BodyDetectedStream =>
      _player1BodyDetectedController.stream;
  Stream<bool> get player2BodyDetectedStream =>
      _player2BodyDetectedController.stream;
  Stream<MultiplayerPoses> get multiplayerPoseStream =>
      _multiplayerPoseController.stream;
  Stream<MultiplayerPoses> get visualMultiplayerPoseStream =>
      _visualMultiplayerPoseController.stream;

  void setEnabled(bool enabled) {
    if (_isDisposed) return;
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;

    if (!enabled) {
      _resetTracks();
      _publishPoses(
        null,
        null,
        player1Visual: null,
        player2Visual: null,
        player1BodyDetected: false,
        player2BodyDetected: false,
      );
    }
  }

  void startProcessing(
    Stream<CameraImage> frameStream,
    CameraDescription camera, {
    CameraDisplayMode displayMode = CameraDisplayMode.portrait,
  }) {
    if (_isDisposed) return;
    _displayMode = displayMode;
    _subscription = frameStream.listen((image) => _processFrame(image, camera));
  }

  Future<void> _processFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isDisposed) return;
    if (!_isEnabled) return;
    if (_isProcessing) {
      _busyFrameDrops++;
      _debugLogIfNeeded('busy-drop');
      return;
    }

    final now = DateTime.now();
    final lastStartedAt = _lastProcessStartedAt;
    if (lastStartedAt != null &&
        now.difference(lastStartedAt) < _minProcessInterval) {
      _throttledFrameDrops++;
      _debugLogIfNeeded('throttle-drop');
      return;
    }

    _lastProcessStartedAt = now;
    _isProcessing = true;

    try {
      final nativeCallStartedAt = DateTime.now();
      final rotationDegrees = effectiveImageRotationDegrees(
        sensorOrientation: camera.sensorOrientation,
        lensDirection: camera.lensDirection,
        displayMode: _displayMode,
      );
      final result = await _channel
          .invokeMethod<List<dynamic>>('processFrame', {
            'width': image.width,
            'height': image.height,
            'rotation': rotationDegrees,
            'planes': image.planes.map((plane) => plane.bytes).toList(),
            'bytesPerRow': image.planes
                .map((plane) => plane.bytesPerRow)
                .toList(),
            'bytesPerPixel': image.planes
                .map((plane) => plane.bytesPerPixel ?? 1)
                .toList(),
          })
          .timeout(const Duration(milliseconds: 1600));
      _lastNativeLatencyMs = DateTime.now()
          .difference(nativeCallStartedAt)
          .inMilliseconds;
      if (_isDisposed) return;
      _nativeErrorCount = 0;

      final poses = _parsePoses(result ?? const []);
      final candidates = poses
          .map(
            (pose) => _candidateForPose(
              pose,
              Size(image.width.toDouble(), image.height.toDouble()),
              camera,
              rotationDegrees,
            ),
          )
          .whereType<_PoseCandidate>()
          .toList(growable: false);

      _processedFrameCount++;

      final assignment = _updateTracking(candidates, now);
      _publishTrackingAssignment(assignment);
      _debugLogIfNeeded(
        'raw:${poses.length} valid:${candidates.length} '
        'track:${assignment.debugLabel}',
      );
    } catch (e) {
      _nativeErrorCount++;
      assert(() {
        debugPrint(
          '[MediaPipeMultiplayerPoseService] Error ($_nativeErrorCount): $e',
        );
        return true;
      }());
      if (_nativeErrorCount >= 3) {
        _nativeErrorCount = 0;
        _resetTracks();
        unawaited(_resetNativeLandmarker());
      }
      final assignment = _updateTracking(const [], DateTime.now());
      _publishTrackingAssignment(assignment);
    } finally {
      _isProcessing = false;
    }
  }

  List<Pose> _parsePoses(List<dynamic> rawPoses) {
    return rawPoses
        .map((rawPose) {
          final landmarks = <PoseLandmarkType, PoseLandmark>{};
          if (rawPose is List) {
            for (final rawLandmark in rawPose) {
              if (rawLandmark is! Map) continue;
              final typeIndex = (rawLandmark['type'] as num?)?.toInt();
              if (typeIndex == null ||
                  typeIndex < 0 ||
                  typeIndex >= PoseLandmarkType.values.length) {
                continue;
              }
              final type = PoseLandmarkType.values[typeIndex];
              landmarks[type] = PoseLandmark(
                type: type,
                x: ((rawLandmark['x'] as num?) ?? 0).toDouble(),
                y: ((rawLandmark['y'] as num?) ?? 0).toDouble(),
                z: ((rawLandmark['z'] as num?) ?? 0).toDouble(),
                likelihood: ((rawLandmark['likelihood'] as num?) ?? 0)
                    .toDouble(),
              );
            }
          }
          return Pose(landmarks: landmarks);
        })
        .toList(growable: false);
  }

  _TrackingAssignment _updateTracking(
    List<_PoseCandidate> candidates,
    DateTime now,
  ) {
    final sorted = candidates.toList(growable: false)
      ..sort((a, b) => a.centerX.compareTo(b.centerX));

    if (_trackPhase == _TrackPhase.searching) {
      final initial = _initialLanePair(sorted);
      if (initial == null) {
        _stableInitialLockFrames = 0;
        _clearTracksIfFullyMissing(now);
        return _currentAssignment(now, 'searching:no-stable-pair');
      }

      _stableInitialLockFrames++;
      if (_stableInitialLockFrames < _initialLockStableFrames) {
        return _currentAssignment(
          now,
          'searching:pair-frame-$_stableInitialLockFrames',
        );
      }

      _player1Track.updateFresh(initial.player1, now);
      _player2Track.updateFresh(initial.player2, now);
      _trackPhase = _TrackPhase.locked;
      return _currentAssignment(now, 'locked:init-left-right');
    }

    final used = <_PoseCandidate>{};
    final player1 = _matchLockedTrack(
      track: _player1Track,
      candidates: sorted,
      used: used,
      now: now,
    );
    if (player1 != null) {
      used.add(player1);
      _player1Track.updateFresh(player1, now);
    }

    final player2 = _matchLockedTrack(
      track: _player2Track,
      candidates: sorted,
      used: used,
      now: now,
    );
    if (player2 != null) {
      used.add(player2);
      _player2Track.updateFresh(player2, now);
    }

    if (_player1Track.isMissingTooLong(now, _fullResetTimeout) &&
        _player2Track.isMissingTooLong(now, _fullResetTimeout)) {
      _resetTracks();
      return _currentAssignment(now, 'reset-missing');
    }

    final label = switch ((player1 != null, player2 != null)) {
      (true, true) => 'locked:fresh-both',
      (true, false) => 'locked:held-p2',
      (false, true) => 'locked:held-p1',
      (false, false) => 'locked:held-both',
    };
    return _currentAssignment(now, label);
  }

  ({_PoseCandidate player1, _PoseCandidate player2})? _initialLanePair(
    List<_PoseCandidate> sorted,
  ) {
    _PoseCandidate? left;
    _PoseCandidate? right;

    for (final candidate in sorted) {
      if (_isInLane(candidate, _PlayerLane.left)) {
        if (left == null ||
            _initialCandidateScore(candidate, _PlayerLane.left) <
                _initialCandidateScore(left, _PlayerLane.left)) {
          left = candidate;
        }
      } else if (_isInLane(candidate, _PlayerLane.right)) {
        if (right == null ||
            _initialCandidateScore(candidate, _PlayerLane.right) <
                _initialCandidateScore(right, _PlayerLane.right)) {
          right = candidate;
        }
      }
    }

    if (left == null || right == null) return null;
    if (right.centerX - left.centerX < _initialLockMinSeparation) return null;
    return (player1: left, player2: right);
  }

  double _initialCandidateScore(_PoseCandidate candidate, _PlayerLane lane) {
    final laneTargetX = switch (lane) {
      _PlayerLane.left => 0.25,
      _PlayerLane.right => 0.75,
    };
    return (candidate.centerX - laneTargetX).abs() +
        (1.0 - candidate.reliability) * 0.2 -
        candidate.bodySize * 0.04;
  }

  _PoseCandidate? _matchLockedTrack({
    required _TrackedPlayer track,
    required List<_PoseCandidate> candidates,
    required Set<_PoseCandidate> used,
    required DateTime now,
  }) {
    final previous = track.candidate;
    if (previous == null) return null;

    _PoseCandidate? best;
    var bestCost = double.infinity;
    final isFresh = track.hasFreshPose(now, _freshPoseTimeout);
    final maxDistance = isFresh
        ? _maxFreshMatchDistance
        : _maxReacquireMatchDistance;

    for (final candidate in candidates) {
      if (used.contains(candidate)) continue;
      if (!_isInLane(candidate, track.lane)) continue;

      final centerDistance = (candidate.center - previous.center).distance;
      if (centerDistance > maxDistance) continue;

      final cost = _assignmentCost(candidate, previous);
      if (cost < bestCost) {
        best = candidate;
        bestCost = cost;
      }
    }

    return best;
  }

  double _assignmentCost(_PoseCandidate candidate, _PoseCandidate previous) {
    final centerDistance = (candidate.center - previous.center).distance;
    final bodySizeDelta = (candidate.bodySize - previous.bodySize).abs();
    final reliabilityPenalty = (1.0 - candidate.reliability) * 0.04;
    return centerDistance + bodySizeDelta * 0.45 + reliabilityPenalty;
  }

  bool _isInLane(_PoseCandidate candidate, _PlayerLane lane) {
    return switch (lane) {
      _PlayerLane.left => candidate.centerX <= _leftLaneMaxX,
      _PlayerLane.right => candidate.centerX >= _rightLaneMinX,
    };
  }

  void _clearTracksIfFullyMissing(DateTime now) {
    if (_player1Track.isMissingTooLong(now, _fullResetTimeout) &&
        _player2Track.isMissingTooLong(now, _fullResetTimeout)) {
      _resetTracks();
    }
  }

  void _resetTracks() {
    _trackPhase = _TrackPhase.searching;
    _stableInitialLockFrames = 0;
    _player1Track.clear();
    _player2Track.clear();
  }

  _TrackingAssignment _currentAssignment(DateTime now, String debugLabel) {
    return _TrackingAssignment(
      player1Fresh: _player1Track.hasFreshPose(now, _freshPoseTimeout)
          ? _player1Track.candidate
          : null,
      player2Fresh: _player2Track.hasFreshPose(now, _freshPoseTimeout)
          ? _player2Track.candidate
          : null,
      player1Visual: _player1Track.hasVisualPose(now, _visualPoseHoldTimeout)
          ? _player1Track.candidate
          : null,
      player2Visual: _player2Track.hasVisualPose(now, _visualPoseHoldTimeout)
          ? _player2Track.candidate
          : null,
      player1Detected: _player1Track.hasVisualPose(now, _visualPoseHoldTimeout),
      player2Detected: _player2Track.hasVisualPose(now, _visualPoseHoldTimeout),
      debugLabel: debugLabel,
    );
  }

  _PoseCandidate? _candidateForPose(
    Pose pose,
    Size imageSize,
    CameraDescription camera,
    int rotationDegrees,
  ) {
    final torsoPoints = <Offset>[];
    var reliabilityTotal = 0.0;
    for (final type in const [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ]) {
      final landmark = pose.landmarks[type];
      if (landmark == null ||
          landmark.likelihood < kMultiplayerRepLandmarkLikelihoodThreshold) {
        continue;
      }
      torsoPoints.add(
        _normalizedPreviewPoint(landmark, imageSize, camera, rotationDegrees),
      );
      reliabilityTotal += landmark.likelihood;
    }

    if (torsoPoints.length < 3) return null;

    final center =
        torsoPoints.reduce((a, b) => a + b) / torsoPoints.length.toDouble();
    var left = torsoPoints.first.dx;
    var top = torsoPoints.first.dy;
    var right = torsoPoints.first.dx;
    var bottom = torsoPoints.first.dy;
    for (final point in torsoPoints.skip(1)) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }

    final bounds = Rect.fromLTRB(left, top, right, bottom);
    final bodySize = math.max(0.01, bounds.size.longestSide);
    return _PoseCandidate(
      pose: pose,
      center: center,
      torsoBounds: bounds,
      bodySize: bodySize,
      reliability: reliabilityTotal / torsoPoints.length,
    );
  }

  void _publishTrackingAssignment(_TrackingAssignment assignment) {
    _publishPoses(
      assignment.player1Fresh?.pose,
      assignment.player2Fresh?.pose,
      player1Visual: assignment.player1Visual?.pose,
      player2Visual: assignment.player2Visual?.pose,
      player1BodyDetected: assignment.player1Detected,
      player2BodyDetected: assignment.player2Detected,
    );
  }

  void _publishPoses(
    Pose? player1,
    Pose? player2, {
    required Pose? player1Visual,
    required Pose? player2Visual,
    required bool player1BodyDetected,
    required bool player2BodyDetected,
  }) {
    if (_isDisposed) return;
    _player1PoseController.add(player1);
    _player2PoseController.add(player2);
    _player1BodyDetectedController.add(player1BodyDetected);
    _player2BodyDetectedController.add(player2BodyDetected);
    _multiplayerPoseController.add(
      MultiplayerPoses(player1: player1, player2: player2),
    );
    _visualMultiplayerPoseController.add(
      MultiplayerPoses(player1: player1Visual, player2: player2Visual),
    );
  }

  Offset _normalizedPreviewPoint(
    PoseLandmark landmark,
    Size imageSize,
    CameraDescription camera,
    int rotationDegrees,
  ) {
    final logicalSize = poseCoordinateSpaceSize(
      inputImageSize: imageSize,
      rotationDegrees: rotationDegrees,
    );
    var normalizedX = (landmark.x / logicalSize.width)
        .clamp(0.0, 1.0)
        .toDouble();
    final normalizedY = (landmark.y / logicalSize.height)
        .clamp(0.0, 1.0)
        .toDouble();

    if (camera.lensDirection == CameraLensDirection.front) {
      normalizedX = 1.0 - normalizedX;
    }
    return Offset(normalizedX, normalizedY);
  }

  void _debugLogIfNeeded(String message) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final lastLoggedAt = _lastDebugLogAt;
    if (lastLoggedAt != null &&
        now.difference(lastLoggedAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastDebugLogAt = now;
    debugPrint(
      '[MP Pose] frame:$_processedFrameCount native:${_lastNativeLatencyMs}ms '
      'busyDrops:$_busyFrameDrops throttleDrops:$_throttledFrameDrops '
      '$message',
    );
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeInternal();
    await _disposeFuture;
  }

  Future<void> _disposeInternal() async {
    _isDisposed = true;
    _isEnabled = false;
    await _subscription?.cancel();
    await _resetNativeLandmarker();
    if (!_player1PoseController.isClosed) {
      await _player1PoseController.close();
    }
    if (!_player2PoseController.isClosed) {
      await _player2PoseController.close();
    }
    if (!_player1BodyDetectedController.isClosed) {
      await _player1BodyDetectedController.close();
    }
    if (!_player2BodyDetectedController.isClosed) {
      await _player2BodyDetectedController.close();
    }
    if (!_multiplayerPoseController.isClosed) {
      await _multiplayerPoseController.close();
    }
    if (!_visualMultiplayerPoseController.isClosed) {
      await _visualMultiplayerPoseController.close();
    }
  }

  Future<void> _resetNativeLandmarker() async {
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {}
  }
}
