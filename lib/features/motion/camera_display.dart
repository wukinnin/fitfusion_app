import 'dart:ui';

import 'package:camera/camera.dart';

enum CameraDisplayMode { portrait, landscapeLeft }

int effectiveImageRotationDegrees({
  required int sensorOrientation,
  required CameraLensDirection lensDirection,
  CameraDisplayMode displayMode = CameraDisplayMode.portrait,
}) {
  final normalizedSensor = ((sensorOrientation % 360) + 360) % 360;
  final deviceDegrees = switch (displayMode) {
    CameraDisplayMode.portrait => 0,
    CameraDisplayMode.landscapeLeft => 90,
  };

  if (lensDirection == CameraLensDirection.front) {
    return (normalizedSensor + deviceDegrees) % 360;
  }

  return (normalizedSensor - deviceDegrees + 360) % 360;
}

Size poseCoordinateSpaceSize({
  required Size inputImageSize,
  required int rotationDegrees,
}) {
  final normalizedRotation = ((rotationDegrees % 360) + 360) % 360;
  final isRotated = normalizedRotation == 90 || normalizedRotation == 270;
  return isRotated
      ? Size(inputImageSize.height, inputImageSize.width)
      : inputImageSize;
}

Offset transformPosePointToDisplay({
  required double x,
  required double y,
  required Size inputImageSize,
  required Size canvasSize,
  required CameraLensDirection lensDirection,
  required int sensorOrientation,
  CameraDisplayMode displayMode = CameraDisplayMode.portrait,
}) {
  final rotationDegrees = effectiveImageRotationDegrees(
    sensorOrientation: sensorOrientation,
    lensDirection: lensDirection,
    displayMode: displayMode,
  );
  final imageSize = poseCoordinateSpaceSize(
    inputImageSize: inputImageSize,
    rotationDegrees: rotationDegrees,
  );

  var normalizedX = x / imageSize.width;
  final normalizedY = y / imageSize.height;

  if (lensDirection == CameraLensDirection.front) {
    normalizedX = 1 - normalizedX;
  }

  final screenAspectRatio = canvasSize.width / canvasSize.height;
  final imageAspectRatio = imageSize.width / imageSize.height;

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
