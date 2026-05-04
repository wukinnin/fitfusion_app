import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants.dart';

class CameraService {
  CameraController? _controller;
  CameraDescription? _selectedCamera;
  int _frameCount = 0;
  bool _isDisposed = false;
  Future<void>? _disposeFuture;

  final StreamController<CameraImage> _frameController =
      StreamController<CameraImage>.broadcast();

  CameraController? get controller => _controller;
  CameraDescription? get cameraDescription => _selectedCamera;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  Stream<CameraImage> get frameStream => _frameController.stream;

  CameraLensDirection get lensDirection =>
      _selectedCamera?.lensDirection ?? CameraLensDirection.front;
  int get sensorOrientation => _selectedCamera?.sensorOrientation ?? 270;

  Future<void> initialize() async {
    if (_isDisposed) return;

    try {
      WidgetsFlutterBinding.ensureInitialized();

      final cameras = await availableCameras();
      if (_isDisposed) return;
      if (cameras.isEmpty) {
        throw CameraException('noCameras', 'No cameras available on device.');
      }

      _selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (_isDisposed) {
        await _controller?.dispose();
        _controller = null;
        return;
      }
      await _controller!.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('CameraService.initialize() failed: $e');
      rethrow;
    }
  }

  void _onFrame(CameraImage image) {
    if (_frameController.isClosed) return;
    _frameCount++;
    if (_frameCount % kFrameSkipCount != 0) return;
    _frameController.add(image);
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeInternal();
    await _disposeFuture;
  }

  Future<void> _disposeInternal() async {
    _isDisposed = true;
    final controller = _controller;
    _controller = null;

    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller?.dispose();

    if (!_frameController.isClosed) {
      await _frameController.close();
    }
  }
}
