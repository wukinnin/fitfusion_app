import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../widgets/pose_overlay_painter.dart';
import '../achievements/achievement_service.dart';
import '../game/fitfusion_game.dart';
import '../game/game_controller.dart';
import '../game/game_session.dart';
import '../motion/camera_service.dart';
import '../motion/pace_monitor.dart';
import '../motion/pose_detector_service.dart';
import '../motion/rep_detector.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  // Motion pipeline
  final CameraService _cameraService = CameraService();
  final PoseDetectorService _poseDetectorService = PoseDetectorService();
  final PaceMonitor _paceMonitor = PaceMonitor();
  RepDetector? _repDetector;

  // Game layer
  FitFusionGame? _game;
  GameController? _gameController;
  final AchievementService _achievementService = AchievementService();

  bool _isInit = false;
  bool _initialized = false;
  String? _error;
  bool _permissionDenied = false;
  bool _sessionEnded = false;

  WorkoutType _workoutType = WorkoutType.squats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is WorkoutType) {
        _workoutType = args;
      }
      _initAll();
      _isInit = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Home button / recent apps → force defeat
    if (state == AppLifecycleState.paused && !_sessionEnded) {
      _game?.forceDefeat();
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  Future<void> _initAll() async {
    try {
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }

      await _achievementService.init();
      await _cameraService.initialize();

      if (_cameraService.cameraDescription != null) {
        _poseDetectorService.startProcessing(
          _cameraService.frameStream,
          _cameraService.cameraDescription!,
        );

        _repDetector = RepDetector(
          workoutType: _workoutType,
          poseStream: _poseDetectorService.poseStream,
        );
      }

      // Create Flame game — configure() before attaching to GameWidget
      _game = FitFusionGame(onSessionComplete: _onSessionComplete);
      _game!.configure(workoutType: _workoutType);

      // Create GameController bridge
      if (_repDetector != null) {
        _gameController = GameController(
          game: _game!,
          repDetector: _repDetector!,
          paceMonitor: _paceMonitor,
          achievementService: _achievementService,
        );
      }

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onSessionComplete(GameSession session) {
    if (_sessionEnded) return;
    _sessionEnded = true;

    // Evaluate achievements and show popups before navigating
    _achievementService.evaluateSession(session).then((newlyUnlocked) {
      if (newlyUnlocked.isNotEmpty && _game != null) {
        for (final _ in newlyUnlocked) {
          _game!.showAchievementPopup();
        }
        // Delay navigation so popups are visible (3s popup duration + buffer)
        Future.delayed(const Duration(milliseconds: 3500), () {
          _navigateToResults(session);
        });
      } else {
        // No achievements — navigate immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToResults(session);
        });
      }
    });
  }

  void _navigateToResults(GameSession session) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/results',
      arguments: session,
    );
  }

  void _onBackPressed() {
    if (_sessionEnded) return;
    _game?.forceDefeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameController?.dispose();
    _paceMonitor.dispose();
    _repDetector?.dispose();
    _cameraService.dispose();
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: AppTheme.bloodRed,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.crimson, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _permissionDenied = false);
                    _initAll();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold),
                  child: const Text('Retry',
                      style: TextStyle(color: AppTheme.bloodRed)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bloodRed,
        body: Center(
          child: Text('Error: $_error',
              style: const TextStyle(color: AppTheme.crimson)),
        ),
      );
    }

    if (!_initialized || _game == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bloodRed,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Layer 1: Camera feed
            CameraPreviewWidget(controller: _cameraService.controller),

            // Layer 2: Pose skeleton overlay (debug only)
            if (kDebugMode)
              StreamBuilder<Pose?>(
                stream: _poseDetectorService.poseStream,
                builder: (context, snapshot) {
                  final pose = snapshot.data;
                  if (_cameraService.controller?.value.previewSize == null) {
                    return const SizedBox.shrink();
                  }
                  return PoseOverlayWidget(
                    pose: pose,
                    inputImageSize:
                        _cameraService.controller!.value.previewSize!,
                    lensDirection: _cameraService.lensDirection,
                    sensorOrientation: _cameraService.sensorOrientation,
                  );
                },
              ),

            // Layer 3: Flame game with transparent background
            GameWidget(game: _game!),
          ],
        ),
      ),
    );
  }
}
