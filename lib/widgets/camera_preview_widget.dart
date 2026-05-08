import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../features/motion/camera_display.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController? controller;
  final CameraDisplayMode displayMode;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    this.displayMode = CameraDisplayMode.portrait,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(color: Colors.black);
    }

    final previewSize = ctrl.value.previewSize!;
    final displaySize = switch (displayMode) {
      CameraDisplayMode.portrait => Size(previewSize.height, previewSize.width),
      CameraDisplayMode.landscapeLeft => Size(
        previewSize.width,
        previewSize.height,
      ),
    };

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }
}
