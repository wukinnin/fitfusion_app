import 'dart:ui';

import 'package:camera/camera.dart';

Offset transformPosePointToScreen({
  required double x,
  required double y,
  required Size inputImageSize,
  required Size canvasSize,
  required CameraLensDirection lensDirection,
  required int sensorOrientation,
}) {
  final isRotated = sensorOrientation == 90 || sensorOrientation == 270;
  final imageLogicalWidth = isRotated
      ? inputImageSize.height
      : inputImageSize.width;
  final imageLogicalHeight = isRotated
      ? inputImageSize.width
      : inputImageSize.height;

  var normalizedX = x / imageLogicalWidth;
  final normalizedY = y / imageLogicalHeight;

  if (lensDirection == CameraLensDirection.front) {
    normalizedX = 1 - normalizedX;
  }

  final screenAspectRatio = canvasSize.width / canvasSize.height;
  final imageAspectRatio = imageLogicalWidth / imageLogicalHeight;

  if (screenAspectRatio > imageAspectRatio) {
    final drawnHeight = canvasSize.width / imageAspectRatio;
    final offsetY = (canvasSize.height - drawnHeight) / 2;
    return Offset(
      normalizedX * canvasSize.width,
      normalizedY * drawnHeight + offsetY,
    );
  }

  final drawnWidth = canvasSize.height * imageAspectRatio;
  final offsetX = (canvasSize.width - drawnWidth) / 2;
  return Offset(
    normalizedX * drawnWidth + offsetX,
    normalizedY * canvasSize.height,
  );
}
