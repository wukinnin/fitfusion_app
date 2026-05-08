import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:fitfusion/features/motion/camera_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveImageRotationDegrees', () {
    test('front camera portrait preserves the existing sensor rotation', () {
      expect(
        effectiveImageRotationDegrees(
          sensorOrientation: 270,
          lensDirection: CameraLensDirection.front,
        ),
        270,
      );
    });

    test('front camera landscape-left uses landscape-correct rotation', () {
      expect(
        effectiveImageRotationDegrees(
          sensorOrientation: 270,
          lensDirection: CameraLensDirection.front,
          displayMode: CameraDisplayMode.landscapeLeft,
        ),
        0,
      );
    });
  });

  group('transformPosePointToDisplay', () {
    test('portrait center maps to canvas center', () {
      final point = transformPosePointToDisplay(
        x: 240,
        y: 320,
        inputImageSize: const Size(640, 480),
        canvasSize: const Size(360, 640),
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 270,
      );

      expect(point.dx, moreOrLessEquals(180));
      expect(point.dy, moreOrLessEquals(320));
    });

    test('landscape-left center maps to canvas center', () {
      final point = transformPosePointToDisplay(
        x: 320,
        y: 240,
        inputImageSize: const Size(640, 480),
        canvasSize: const Size(640, 480),
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
        displayMode: CameraDisplayMode.landscapeLeft,
      );

      expect(point.dx, moreOrLessEquals(320));
      expect(point.dy, moreOrLessEquals(240));
    });

    test('front camera landmarks are mirrored horizontally', () {
      final rawLeft = transformPosePointToDisplay(
        x: 160,
        y: 240,
        inputImageSize: const Size(640, 480),
        canvasSize: const Size(640, 480),
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
        displayMode: CameraDisplayMode.landscapeLeft,
      );
      final rawRight = transformPosePointToDisplay(
        x: 480,
        y: 240,
        inputImageSize: const Size(640, 480),
        canvasSize: const Size(640, 480),
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
        displayMode: CameraDisplayMode.landscapeLeft,
      );

      expect(rawLeft.dx, greaterThan(rawRight.dx));
      expect(rawLeft.dy, moreOrLessEquals(rawRight.dy));
    });
  });
}
