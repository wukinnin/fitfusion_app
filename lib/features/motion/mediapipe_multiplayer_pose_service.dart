import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/constants.dart';
import 'pose_detector_service.dart';

class _SortedPose {
  final Pose pose;
  final double centerX;

  const _SortedPose({required this.pose, required this.centerX});
}

class MediaPipeMultiplayerPoseService {
  static const MethodChannel _channel = MethodChannel(
    'fitfusion/mediapipe_pose',
  );

  StreamSubscription? _subscription;
  final StreamController<Pose?> _player1PoseController =
      StreamController<Pose?>.broadcast();
  final StreamController<Pose?> _player2PoseController =
      StreamController<Pose?>.broadcast();
  final StreamController<MultiplayerPoses> _multiplayerPoseController =
      StreamController<MultiplayerPoses>.broadcast();
  final Duration _minProcessInterval = const Duration(
    milliseconds: 1000 ~/ kPoseDetectionTargetFps,
  );

  bool _isProcessing = false;
  bool _isEnabled = false;
  bool _isDisposed = false;
  DateTime? _lastProcessStartedAt;
  Future<void>? _disposeFuture;

  Stream<Pose?> get player1PoseStream => _player1PoseController.stream;
  Stream<Pose?> get player2PoseStream => _player2PoseController.stream;
  Stream<MultiplayerPoses> get multiplayerPoseStream =>
      _multiplayerPoseController.stream;

  void setEnabled(bool enabled) {
    if (_isDisposed) return;
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;

    if (!enabled) {
      _publishPoses(null, null);
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
      if (_isDisposed) return;

      final poses = _parsePoses(result ?? const []);
      final validPoses = poses
          .where(_areCriticalLandmarksReliable)
          .toList(growable: false);

      if (validPoses.isEmpty) {
        _publishPoses(null, null);
        return;
      }

      _publishLanePoses(
        validPoses,
        Size(image.width.toDouble(), image.height.toDouble()),
        camera,
      );
    } catch (e) {
      assert(() {
        debugPrint('[MediaPipeMultiplayerPoseService] Error: $e');
        return true;
      }());
      _publishPoses(null, null);
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

  void _publishLanePoses(
    List<Pose> poses,
    Size imageSize,
    CameraDescription camera,
  ) {
    // Sort all detected bodies left-to-right on the preview. With MediaPipe
    // configured for numPoses=2, we want to always surface BOTH bodies when
    // two are detected — assigning the leftmost to Player 1 and the rightmost
    // to Player 2 regardless of where the midpoint lands. A strict
    // "centerX < 0.5 → P1, else P2" split used to drop one body when both
    // players happened to stand on the same half of the frame.
    final sorted =
        poses.map((pose) {
            return _SortedPose(
              pose: pose,
              centerX: _bodyCenterXOnPreview(pose, imageSize, camera),
            );
          }).toList(growable: false)
          ..sort((a, b) => a.centerX.compareTo(b.centerX));

    if (sorted.isEmpty) {
      _publishPoses(null, null);
      return;
    }

    if (sorted.length == 1) {
      // Only one body visible — keep it on the lane it physically occupies so
      // the correct player's rep detector receives it.
      final only = sorted.first;
      if (only.centerX < 0.5) {
        _publishPoses(only.pose, null);
      } else {
        _publishPoses(null, only.pose);
      }
      return;
    }

    _publishPoses(sorted.first.pose, sorted.last.pose);
  }

  void _publishPoses(Pose? player1, Pose? player2) {
    if (_isDisposed) return;
    _player1PoseController.add(player1);
    _player2PoseController.add(player2);
    _multiplayerPoseController.add(
      MultiplayerPoses(player1: player1, player2: player2),
    );
  }

  bool _areCriticalLandmarksReliable(Pose pose) {
    const criticalLandmarks = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    // In multiplayer, the second body is often partially occluded or at the
    // edge of the frame, which drags MediaPipe's visibility scores below the
    // strict singleplayer threshold. Use the more forgiving multiplayer
    // threshold so we don't discard an otherwise valid second body and
    // collapse to a single-player feed.
    for (final type in criticalLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark == null) return false;
      if (landmark.likelihood < kMultiplayerRepLandmarkLikelihoodThreshold) {
        return false;
      }
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
    if (!_multiplayerPoseController.isClosed) {
      await _multiplayerPoseController.close();
    }
  }
}
