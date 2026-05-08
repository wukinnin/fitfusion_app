import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/constants.dart';
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

class _PlayerPoseTrack {
  _PoseCandidate? _lastCandidate;
  DateTime? _lastFreshAt;

  bool get hasCandidate => _lastCandidate != null;

  _PoseCandidate? get lastCandidate => _lastCandidate;

  void update(_PoseCandidate candidate, DateTime now) {
    _lastCandidate = candidate;
    _lastFreshAt = now;
  }

  void clear() {
    _lastCandidate = null;
    _lastFreshAt = null;
  }

  bool isPresent(DateTime now, Duration gracePeriod) {
    final lastFreshAt = _lastFreshAt;
    return lastFreshAt != null && now.difference(lastFreshAt) <= gracePeriod;
  }
}

class MediaPipeMultiplayerPoseService {
  static const MethodChannel _channel = MethodChannel(
    'fitfusion/mediapipe_pose',
  );
  static const Duration _trackGracePeriod = Duration(milliseconds: 300);
  static const double _maxSingleCandidateTrackDistance = 0.30;

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
  final Duration _minProcessInterval = const Duration(
    milliseconds: 1000 ~/ kPoseDetectionTargetFps,
  );
  final _player1Track = _PlayerPoseTrack();
  final _player2Track = _PlayerPoseTrack();

  bool _isProcessing = false;
  bool _isEnabled = false;
  bool _isDisposed = false;
  DateTime? _lastProcessStartedAt;
  DateTime? _lastDebugLogAt;
  int _busyFrameDrops = 0;
  int _throttledFrameDrops = 0;
  int _processedFrameCount = 0;
  int _lastNativeLatencyMs = 0;
  Future<void>? _disposeFuture;

  Stream<Pose?> get player1PoseStream => _player1PoseController.stream;
  Stream<Pose?> get player2PoseStream => _player2PoseController.stream;
  Stream<bool> get player1BodyDetectedStream =>
      _player1BodyDetectedController.stream;
  Stream<bool> get player2BodyDetectedStream =>
      _player2BodyDetectedController.stream;
  Stream<MultiplayerPoses> get multiplayerPoseStream =>
      _multiplayerPoseController.stream;

  void setEnabled(bool enabled) {
    if (_isDisposed) return;
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;

    if (!enabled) {
      _player1Track.clear();
      _player2Track.clear();
      _publishPoses(
        null,
        null,
        player1BodyDetected: false,
        player2BodyDetected: false,
      );
    }
  }

  void startProcessing(
    Stream<CameraImage> frameStream,
    CameraDescription camera,
  ) {
    if (_isDisposed) return;
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
      final result = await _channel
          .invokeMethod<List<dynamic>>('processFrame', {
            'width': image.width,
            'height': image.height,
            'rotation': camera.sensorOrientation,
            'planes': image.planes.map((plane) => plane.bytes).toList(),
            'bytesPerRow': image.planes
                .map((plane) => plane.bytesPerRow)
                .toList(),
            'bytesPerPixel': image.planes
                .map((plane) => plane.bytesPerPixel ?? 1)
                .toList(),
          });
      _lastNativeLatencyMs = DateTime.now()
          .difference(nativeCallStartedAt)
          .inMilliseconds;
      if (_isDisposed) return;

      final poses = _parsePoses(result ?? const []);
      final candidates = poses
          .map(
            (pose) => _candidateForPose(
              pose,
              Size(image.width.toDouble(), image.height.toDouble()),
              camera,
            ),
          )
          .whereType<_PoseCandidate>()
          .toList(growable: false);

      _processedFrameCount++;

      if (candidates.isEmpty) {
        _publishTrackedPoses(null, null, now);
        _debugLogIfNeeded('raw:${poses.length} valid:0 assign:none');
        return;
      }

      final assignment = _assignCandidates(candidates, now);
      _publishTrackedPoses(assignment.player1, assignment.player2, now);
      _debugLogIfNeeded(
        'raw:${poses.length} valid:${candidates.length} '
        'assign:${assignment.debugLabel}',
      );
    } catch (e) {
      assert(() {
        debugPrint('[MediaPipeMultiplayerPoseService] Error: $e');
        return true;
      }());
      _publishTrackedPoses(null, null, DateTime.now());
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

  _MultiplayerAssignment _assignCandidates(
    List<_PoseCandidate> candidates,
    DateTime now,
  ) {
    final sorted = candidates.toList(growable: false)
      ..sort((a, b) => a.centerX.compareTo(b.centerX));

    if (sorted.length >= 2) {
      final left = sorted.first;
      final right = sorted.last;

      final p1Track = _player1Track.lastCandidate;
      final p2Track = _player2Track.lastCandidate;
      if (_player1Track.isPresent(now, _trackGracePeriod) &&
          _player2Track.isPresent(now, _trackGracePeriod) &&
          p1Track != null &&
          p2Track != null) {
        final directCost =
            _assignmentCost(left, p1Track) + _assignmentCost(right, p2Track);
        final swappedCost =
            _assignmentCost(right, p1Track) + _assignmentCost(left, p2Track);
        if (swappedCost < directCost) {
          return _MultiplayerAssignment(
            player1: right,
            player2: left,
            debugLabel: 'swap-tracked',
          );
        }
        return _MultiplayerAssignment(
          player1: left,
          player2: right,
          debugLabel: 'direct-tracked',
        );
      }

      return _MultiplayerAssignment(
        player1: left,
        player2: right,
        debugLabel: 'init-left-right',
      );
    }

    final only = sorted.first;
    final p1Cost = _trackCandidateCost(
      track: _player1Track,
      candidate: only,
      now: now,
    );
    final p2Cost = _trackCandidateCost(
      track: _player2Track,
      candidate: only,
      now: now,
    );

    if (p1Cost != null || p2Cost != null) {
      final normalizedP1Cost = p1Cost ?? double.infinity;
      final normalizedP2Cost = p2Cost ?? double.infinity;
      if (math.min(normalizedP1Cost, normalizedP2Cost) <=
          _maxSingleCandidateTrackDistance) {
        if (normalizedP1Cost <= normalizedP2Cost) {
          return _MultiplayerAssignment(
            player1: only,
            player2: null,
            debugLabel: 'single-near-p1',
          );
        }
        return _MultiplayerAssignment(
          player1: null,
          player2: only,
          debugLabel: 'single-near-p2',
        );
      }
    }

    if (only.centerX < 0.5) {
      return _MultiplayerAssignment(
        player1: only,
        player2: null,
        debugLabel: 'single-left-fallback',
      );
    }
    return _MultiplayerAssignment(
      player1: null,
      player2: only,
      debugLabel: 'single-right-fallback',
    );
  }

  double? _trackCandidateCost({
    required _PlayerPoseTrack track,
    required _PoseCandidate candidate,
    required DateTime now,
  }) {
    final trackCandidate = track.lastCandidate;
    if (trackCandidate == null || !track.isPresent(now, _trackGracePeriod)) {
      return null;
    }
    return _assignmentCost(candidate, trackCandidate);
  }

  double _assignmentCost(_PoseCandidate candidate, _PoseCandidate previous) {
    final centerDistance = (candidate.center - previous.center).distance;
    final bodySizeDelta = (candidate.bodySize - previous.bodySize).abs();
    final reliabilityBoost = (1.0 - candidate.reliability) * 0.04;
    return centerDistance + bodySizeDelta * 0.5 + reliabilityBoost;
  }

  _PoseCandidate? _candidateForPose(
    Pose pose,
    Size imageSize,
    CameraDescription camera,
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
      torsoPoints.add(_normalizedPreviewPoint(landmark, imageSize, camera));
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

  void _publishTrackedPoses(
    _PoseCandidate? player1,
    _PoseCandidate? player2,
    DateTime now,
  ) {
    if (player1 != null) {
      _player1Track.update(player1, now);
    }
    if (player2 != null) {
      _player2Track.update(player2, now);
    }

    _publishPoses(
      player1?.pose,
      player2?.pose,
      player1BodyDetected: _player1Track.isPresent(now, _trackGracePeriod),
      player2BodyDetected: _player2Track.isPresent(now, _trackGracePeriod),
    );
  }

  void _publishPoses(
    Pose? player1,
    Pose? player2, {
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
  }

  Offset _normalizedPreviewPoint(
    PoseLandmark landmark,
    Size imageSize,
    CameraDescription camera,
  ) {
    final isRotated =
        camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
    final imageLogicalWidth = isRotated ? imageSize.height : imageSize.width;
    final imageLogicalHeight = isRotated ? imageSize.width : imageSize.height;
    var normalizedX = (landmark.x / imageLogicalWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    final normalizedY = (landmark.y / imageLogicalHeight)
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
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {}
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
  }
}

class _MultiplayerAssignment {
  final _PoseCandidate? player1;
  final _PoseCandidate? player2;
  final String debugLabel;

  const _MultiplayerAssignment({
    required this.player1,
    required this.player2,
    required this.debugLabel,
  });
}
