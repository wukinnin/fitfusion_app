import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/constants.dart';
import 'motion_state.dart';

class MultiplayerPoses {
  final Pose? player1;
  final Pose? player2;

  const MultiplayerPoses({required this.player1, required this.player2});
}

class _LanePoseCandidate {
  final Pose pose;
  final double centerX;

  const _LanePoseCandidate({required this.pose, required this.centerX});
}

class PoseDetectorService {
  late final PoseDetector _detector;
  StreamSubscription? _subscription;
  final StreamController<Pose?> _poseController =
      StreamController<Pose?>.broadcast();
  final StreamController<Pose?> _player1PoseController =
      StreamController<Pose?>.broadcast();
  final StreamController<Pose?> _player2PoseController =
      StreamController<Pose?>.broadcast();
  final StreamController<MultiplayerPoses> _multiplayerPoseController =
      StreamController<MultiplayerPoses>.broadcast();
  final StreamController<MotionState> _motionStateController =
      StreamController<MotionState>.broadcast();
  final Duration _minProcessInterval = const Duration(
    milliseconds: 1000 ~/ kPoseDetectionTargetFps,
  );
  bool _isProcessing = false;
  bool _isEnabled = false;
  bool _hasWarnedUnexpectedFormat = false;
  DateTime? _lastProcessStartedAt;
  Uint8List? _frameBuffer;
  MotionState _lastMotionState = MotionState.empty();
  bool _isDisposed = false;
  Future<void>? _disposeFuture;

  PoseDetectorService() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Stream<Pose?> get poseStream => _poseController.stream;
  Stream<Pose?> get player1PoseStream => _player1PoseController.stream;
  Stream<Pose?> get player2PoseStream => _player2PoseController.stream;
  Stream<MultiplayerPoses> get multiplayerPoseStream =>
      _multiplayerPoseController.stream;
  Stream<MotionState> get motionStateStream => _motionStateController.stream;

  void setEnabled(bool enabled) {
    if (_isDisposed) return;
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;

    if (!enabled) {
      _poseController.add(null);
      _publishMultiplayerPoses(null, null);
      _motionStateController.add(_lastMotionState.asStale(DateTime.now()));
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
    if (_isProcessing) return;

    final now = DateTime.now();
    final lastStartedAt = _lastProcessStartedAt;
    if (lastStartedAt != null &&
        now.difference(lastStartedAt) < _minProcessInterval) {
      return;
    }

    _lastProcessStartedAt = now;
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) {
        _publishNoPose();
        return;
      }

      final poses = await _detector.processImage(inputImage);

      if (poses.isEmpty) {
        _publishNoPose();
        return;
      }

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final validPoses = poses
          .where(_areCriticalLandmarksReliable)
          .toList(growable: false);

      if (validPoses.isEmpty) {
        _publishNoPose();
        return;
      }

      final pose = validPoses.first;
      final laneCandidates =
          validPoses
              .map(
                (pose) => _LanePoseCandidate(
                  pose: pose,
                  centerX: _bodyCenterXOnPreview(pose, imageSize, camera),
                ),
              )
              .toList()
            ..sort((a, b) => a.centerX.compareTo(b.centerX));

      if (_isDisposed) return;

      _poseController.add(pose);
      _publishMultiplayerLanePoses(laneCandidates);
      _lastMotionState = _buildMotionState(pose, imageSize);
      _motionStateController.add(_lastMotionState);
    } catch (e) {
      assert(() {
        debugPrint('[PoseDetectorService] Error processing frame: $e');
        return true;
      }());
      _publishNoPose();
    } finally {
      _isProcessing = false;
    }
  }

  void _publishNoPose() {
    if (_isDisposed) return;
    _poseController.add(null);
    _publishMultiplayerPoses(null, null);
    _motionStateController.add(_lastMotionState.asStale(DateTime.now()));
  }

  void _publishMultiplayerPoses(Pose? player1, Pose? player2) {
    if (_isDisposed) return;
    _player1PoseController.add(player1);
    _player2PoseController.add(player2);
    _multiplayerPoseController.add(
      MultiplayerPoses(player1: player1, player2: player2),
    );
  }

  void _publishMultiplayerLanePoses(List<_LanePoseCandidate> candidates) {
    _LanePoseCandidate? leftLane;
    _LanePoseCandidate? rightLane;

    for (final candidate in candidates) {
      if (candidate.centerX < 0.5) {
        if (leftLane == null || candidate.centerX > leftLane.centerX) {
          leftLane = candidate;
        }
      } else {
        if (rightLane == null || candidate.centerX < rightLane.centerX) {
          rightLane = candidate;
        }
      }
    }

    _publishMultiplayerPoses(leftLane?.pose, rightLane?.pose);
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    // Determine rotation from camera sensor orientation
    // Front camera on Android is typically 270 degrees
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    // Map sensor orientation degrees to InputImageRotation enum
    switch (sensorOrientation) {
      case 0:
        rotation = InputImageRotation.rotation0deg;
        break;
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation270deg; // front camera default
    }

    // Verify format is supported
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // On Android, we expect NV21 (17) or YUV_420_888 (35)
    if (!_hasWarnedUnexpectedFormat &&
        (format == null ||
            (format != InputImageFormat.nv21 &&
                format != InputImageFormat.yuv_420_888))) {
      _hasWarnedUnexpectedFormat = true;
      assert(() {
        debugPrint(
          '[PoseDetectorService] Warning: Unexpected image format: ${image.format.raw}',
        );
        return true;
      }());
    }

    // WORKAROUND: ML Kit on Android often throws "ImageFormat is not supported" for YUV_420_888 (35).
    // However, it supports NV21 (17).
    // If we receive YUV_420_888, we lie and say it's NV21.
    // The byte structure (concatenated planes) is compatible enough for pose detection
    // (though chroma channels might be swapped, which doesn't affect the skeleton much).
    final processingFormat = (format == InputImageFormat.yuv_420_888)
        ? InputImageFormat.nv21
        : (format ?? InputImageFormat.nv21);

    // Concatenate all plane bytes
    // Optimization: Pre-calculate size and allocate once to avoid WriteBuffer overhead
    int totalBytes = 0;
    for (final Plane plane in image.planes) {
      totalBytes += plane.bytes.length;
    }

    // Reuse buffer if possible to avoid GC
    if (_frameBuffer == null || _frameBuffer!.length != totalBytes) {
      _frameBuffer = Uint8List(totalBytes);
    }

    int offset = 0;
    for (final Plane plane in image.planes) {
      _frameBuffer!.setAll(offset, plane.bytes);
      offset += plane.bytes.length;
    }

    return InputImage.fromBytes(
      bytes: _frameBuffer!,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: processingFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  bool _areCriticalLandmarksReliable(Pose pose) {
    const criticalLandmarks = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final type in criticalLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark == null) return false;
      if (landmark.likelihood < kLandmarkLikelihoodThreshold) return false;
    }
    return true;
  }

  double _bodyCenterXOnPreview(
    Pose pose,
    Size imageSize,
    CameraDescription camera,
  ) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip]!;
    final centerX =
        (leftShoulder.x + rightShoulder.x + leftHip.x + rightHip.x) / 4;

    final isRotated =
        camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
    final imageLogicalWidth = isRotated ? imageSize.height : imageSize.width;
    var normalizedX = (centerX / imageLogicalWidth).clamp(0.0, 1.0).toDouble();

    if (camera.lensDirection == CameraLensDirection.front) {
      normalizedX = 1.0 - normalizedX;
    }
    return normalizedX;
  }

  MotionState _buildMotionState(Pose pose, Size imageSize) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip]!;
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    final hipCenterX = (leftHip.x + rightHip.x) / 2;
    final hipCenterY = (leftHip.y + rightHip.y) / 2;
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
    final center = Offset(
      ((hipCenterX + shoulderCenterX) / 2 / imageSize.width)
          .clamp(0.0, 1.0)
          .toDouble(),
      ((hipCenterY + shoulderCenterY) / 2 / imageSize.height)
          .clamp(0.0, 1.0)
          .toDouble(),
    );

    final confidence =
        (leftShoulder.likelihood +
            rightShoulder.likelihood +
            leftHip.likelihood +
            rightHip.likelihood) /
        4;

    final leftArmRaised = _isAboveShoulder(leftWrist, leftShoulder);
    final rightArmRaised = _isAboveShoulder(rightWrist, rightShoulder);
    final ankleSpread = (leftAnkle != null && rightAnkle != null)
        ? _distance(leftAnkle, rightAnkle)
        : 0.0;
    final isJumping =
        shoulderWidth > 0 &&
        leftArmRaised &&
        rightArmRaised &&
        ankleSpread / shoulderWidth > 1.1;
    final isSquatting = _isSquatLike(
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
    );
    final sideCrunch =
        shoulderWidth > 0 &&
        (_isClose(leftElbow, leftKnee, shoulderWidth) ||
            _isClose(rightElbow, rightKnee, shoulderWidth));

    final action = isJumping
        ? DetectedAction.jumpingJack
        : isSquatting
        ? DetectedAction.squatting
        : sideCrunch
        ? DetectedAction.sideCrunch
        : DetectedAction.none;

    return MotionState(
      action: action,
      bodyCenter: center,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      leftArmRaised: leftArmRaised,
      rightArmRaised: rightArmRaised,
      isSquatting: isSquatting,
      isJumping: isJumping,
      timestamp: DateTime.now(),
    );
  }

  bool _isAboveShoulder(PoseLandmark? wrist, PoseLandmark shoulder) {
    return wrist != null &&
        wrist.likelihood >= kLandmarkLikelihoodThreshold &&
        wrist.y < shoulder.y;
  }

  bool _isSquatLike(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftHip,
    PoseLandmark rightHip,
    PoseLandmark? leftKnee,
    PoseLandmark? rightKnee,
  ) {
    final leftDelta =
        (leftKnee != null &&
            leftKnee.likelihood >= kLandmarkLikelihoodThreshold)
        ? leftKnee.y - leftHip.y
        : null;
    final rightDelta =
        (rightKnee != null &&
            rightKnee.likelihood >= kLandmarkLikelihoodThreshold)
        ? rightKnee.y - rightHip.y
        : null;
    final delta = switch ((leftDelta, rightDelta)) {
      (final double left, final double right) => (left + right) / 2,
      (final double left, null) => left,
      (null, final double right) => right,
      _ => null,
    };
    if (delta == null) return false;

    final shoulderHipHeight =
        ((leftHip.y + rightHip.y) / 2) -
        ((leftShoulder.y + rightShoulder.y) / 2);
    if (shoulderHipHeight <= 0) return false;
    return delta / shoulderHipHeight < 0.35;
  }

  bool _isClose(PoseLandmark? a, PoseLandmark? b, double refWidth) {
    if (a == null || b == null || refWidth <= 0) return false;
    if (a.likelihood < kLandmarkLikelihoodThreshold ||
        b.likelihood < kLandmarkLikelihoodThreshold) {
      return false;
    }
    return _distance(a, b) / refWidth < kCrunchElbowKneeCrunchThreshold;
  }

  double _distance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeInternal();
    await _disposeFuture;
  }

  Future<void> _disposeInternal() async {
    _isDisposed = true;
    _isEnabled = false;
    await _subscription?.cancel();
    await _detector.close();
    if (!_poseController.isClosed) {
      await _poseController.close();
    }
    if (!_player1PoseController.isClosed) {
      await _player1PoseController.close();
    }
    if (!_player2PoseController.isClosed) {
      await _player2PoseController.close();
    }
    if (!_multiplayerPoseController.isClosed) {
      await _multiplayerPoseController.close();
    }
    if (!_motionStateController.isClosed) {
      await _motionStateController.close();
    }
  }
}
