import 'dart:ui';

import 'package:camera/camera.dart';

import 'camera_display.dart';

Offset transformPosePointToScreen({
  required double x,
  required double y,
  required Size inputImageSize,
  required Size canvasSize,
  required CameraLensDirection lensDirection,
  required int sensorOrientation,
  CameraDisplayMode displayMode = CameraDisplayMode.portrait,
}) {
  return transformPosePointToDisplay(
    x: x,
    y: y,
    inputImageSize: inputImageSize,
    canvasSize: canvasSize,
    lensDirection: lensDirection,
    sensorOrientation: sensorOrientation,
    displayMode: displayMode,
  );
}
