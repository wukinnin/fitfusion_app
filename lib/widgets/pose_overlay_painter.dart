import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants.dart';

class PoseOverlayWidget extends StatelessWidget {
  final Pose? pose;
  final Size inputImageSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  const PoseOverlayWidget({
    super.key,
    required this.pose,
    required this.inputImageSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  @override
  Widget build(BuildContext context) {
    if (pose == null) return const SizedBox.shrink();

    return SizedBox.expand(
      child: CustomPaint(
        painter: PoseOverlayPainter(
          pose: pose!,
          inputImageSize: inputImageSize,
          lensDirection: lensDirection,
          sensorOrientation: sensorOrientation,
        ),
      ),
    );
  }
}

class MultiplayerPoseOverlayWidget extends StatelessWidget {
  final Pose? player1Pose;
  final Pose? player2Pose;
  final Size inputImageSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  const MultiplayerPoseOverlayWidget({
    super.key,
    required this.player1Pose,
    required this.player2Pose,
    required this.inputImageSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  @override
  Widget build(BuildContext context) {
    if (player1Pose == null && player2Pose == null) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: CustomPaint(
        painter: MultiplayerPoseOverlayPainter(
          player1Pose: player1Pose,
          player2Pose: player2Pose,
          inputImageSize: inputImageSize,
          lensDirection: lensDirection,
          sensorOrientation: sensorOrientation,
        ),
      ),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  final Pose pose;
  final Size inputImageSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;
  final Paint _paint;
  final Paint _linePaint;

  PoseOverlayPainter({
    required this.pose,
    required this.inputImageSize,
    required this.lensDirection,
    required this.sensorOrientation,
  }) : _paint = Paint()
         ..color = Colors.greenAccent
         ..style = PaintingStyle.fill,
       _linePaint = Paint()
         ..color = Colors.greenAccent.withValues(alpha: 0.5)
         ..strokeWidth = 2
         ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw landmarks
    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < kLandmarkLikelihoodThreshold) continue;

      final offset = _transformCoordinates(landmark.x, landmark.y, size);

      canvas.drawCircle(offset, 4, _paint);
    }

    // Draw connections
    void drawLine(PoseLandmarkType startType, PoseLandmarkType endType) {
      final start = pose.landmarks[startType];
      final end = pose.landmarks[endType];

      if (start == null || end == null) return;
      if (start.likelihood < kLandmarkLikelihoodThreshold ||
          end.likelihood < kLandmarkLikelihoodThreshold) {
        return;
      }

      final startOffset = _transformCoordinates(start.x, start.y, size);
      final endOffset = _transformCoordinates(end.x, end.y, size);

      canvas.drawLine(startOffset, endOffset, _linePaint);
    }

    // Torso
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Arms
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Legs
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  Offset _transformCoordinates(double x, double y, Size canvasSize) {
    // 1. Determine the logical size of the ML Kit output space
    // If rotation metadata was used, ML Kit likely returns coordinates in the UPRIGHT space.
    // However, inputImageSize is the raw buffer size (usually Landscape).
    // If sensor is 90/270, the ML Kit space is swapped (Portrait).
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double imageLogicalWidth = isRotated
        ? inputImageSize.height
        : inputImageSize.width;
    final double imageLogicalHeight = isRotated
        ? inputImageSize.width
        : inputImageSize.height;

    // 2. Normalize coordinates to [0, 1] based on logical size
    double normalizedX = x / imageLogicalWidth;
    double normalizedY = y / imageLogicalHeight;

    // 3. Mirror if FRONT camera (Flip X)
    // Front camera preview is mirrored. ML Kit detection is "reality".
    // Flip X to match preview.
    if (lensDirection == CameraLensDirection.front) {
      normalizedX = 1 - normalizedX;
    }

    // Note: No explicit rotation step here because ML Kit + Metadata = Upright Coordinates.

    // 4. Scale to fit canvas (BoxFit.cover logic)
    // We need to determine the scale factor that covers the screen
    final double screenAspectRatio = canvasSize.width / canvasSize.height;
    final double imageAspectRatio = imageLogicalWidth / imageLogicalHeight;

    double scale, offsetX, offsetY;

    if (screenAspectRatio > imageAspectRatio) {
      // Screen is wider than image (crop top/bottom)
      // Fit width
      scale = canvasSize.width;

      // Calculate drawn height preserving aspect ratio
      final double drawnHeight = canvasSize.width / imageAspectRatio;

      offsetX = 0;
      offsetY = (canvasSize.height - drawnHeight) / 2;

      return Offset(
        normalizedX * scale + offsetX,
        normalizedY * drawnHeight + offsetY,
      );
    } else {
      // Screen is taller/narrower (crop left/right)
      // Fit height
      final double drawnHeight = canvasSize.height;
      final double drawnWidth = canvasSize.height * imageAspectRatio;

      offsetX = (canvasSize.width - drawnWidth) / 2;
      offsetY = 0;

      return Offset(
        normalizedX * drawnWidth + offsetX,
        normalizedY * drawnHeight + offsetY,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.inputImageSize != inputImageSize ||
        oldDelegate.lensDirection != lensDirection ||
        oldDelegate.sensorOrientation != sensorOrientation;
  }
}

class MultiplayerPoseOverlayPainter extends CustomPainter {
  final Pose? player1Pose;
  final Pose? player2Pose;
  final Size inputImageSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  MultiplayerPoseOverlayPainter({
    required this.player1Pose,
    required this.player2Pose,
    required this.inputImageSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintPose(
      canvas,
      size,
      player1Pose,
      'P1',
      Colors.lightBlueAccent,
      Colors.lightBlueAccent.withValues(alpha: 0.55),
    );
    _paintPose(
      canvas,
      size,
      player2Pose,
      'P2',
      Colors.orangeAccent,
      Colors.orangeAccent.withValues(alpha: 0.55),
    );
  }

  void _paintPose(
    Canvas canvas,
    Size size,
    Pose? pose,
    String label,
    Color pointColor,
    Color lineColor,
  ) {
    if (pose == null) return;

    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    Offset? labelAnchor;

    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < kLandmarkLikelihoodThreshold) continue;
      final offset = _transformCoordinates(landmark.x, landmark.y, size);
      labelAnchor ??= offset;
      canvas.drawCircle(offset, 4, pointPaint);
    }

    void drawLine(PoseLandmarkType startType, PoseLandmarkType endType) {
      final start = pose.landmarks[startType];
      final end = pose.landmarks[endType];

      if (start == null || end == null) return;
      if (start.likelihood < kLandmarkLikelihoodThreshold ||
          end.likelihood < kLandmarkLikelihoodThreshold) {
        return;
      }

      final startOffset = _transformCoordinates(start.x, start.y, size);
      final endOffset = _transformCoordinates(end.x, end.y, size);
      canvas.drawLine(startOffset, endOffset, linePaint);
    }

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    _drawLabel(canvas, label, labelAnchor, pointColor);
  }

  void _drawLabel(Canvas canvas, String text, Offset? anchor, Color color) {
    if (anchor == null) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, anchor.translate(8, -24));
  }

  Offset _transformCoordinates(double x, double y, Size canvasSize) {
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double imageLogicalWidth = isRotated
        ? inputImageSize.height
        : inputImageSize.width;
    final double imageLogicalHeight = isRotated
        ? inputImageSize.width
        : inputImageSize.height;

    double normalizedX = x / imageLogicalWidth;
    double normalizedY = y / imageLogicalHeight;

    if (lensDirection == CameraLensDirection.front) {
      normalizedX = 1 - normalizedX;
    }

    final double screenAspectRatio = canvasSize.width / canvasSize.height;
    final double imageAspectRatio = imageLogicalWidth / imageLogicalHeight;

    if (screenAspectRatio > imageAspectRatio) {
      final double drawnHeight = canvasSize.width / imageAspectRatio;
      final double offsetY = (canvasSize.height - drawnHeight) / 2;

      return Offset(
        normalizedX * canvasSize.width,
        normalizedY * drawnHeight + offsetY,
      );
    } else {
      final double drawnWidth = canvasSize.height * imageAspectRatio;
      final double offsetX = (canvasSize.width - drawnWidth) / 2;

      return Offset(
        normalizedX * drawnWidth + offsetX,
        normalizedY * canvasSize.height,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MultiplayerPoseOverlayPainter oldDelegate) {
    return oldDelegate.player1Pose != player1Pose ||
        oldDelegate.player2Pose != player2Pose ||
        oldDelegate.inputImageSize != inputImageSize ||
        oldDelegate.lensDirection != lensDirection ||
        oldDelegate.sensorOrientation != sensorOrientation;
  }
}
