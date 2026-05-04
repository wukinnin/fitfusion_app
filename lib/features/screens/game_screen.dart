import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../services/app_bgm_service.dart';
import '../../services/notification_service.dart';
import '../../services/session_service.dart';
import '../knight/knight_service.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../widgets/pose_overlay_painter.dart';
import '../achievements/achievement_service.dart';
import '../game/fitfusion_game.dart';
import '../game/game_controller.dart';
import '../game/game_launch_args.dart';
import '../game/game_session.dart';
import '../motion/camera_service.dart';
import '../motion/mediapipe_multiplayer_pose_service.dart';
import '../motion/pace_monitor.dart';
import '../motion/pose_detector_service.dart';
import '../motion/pose_screen_mapper.dart';
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
  final MediaPipeMultiplayerPoseService _multiplayerPoseDetectorService =
      MediaPipeMultiplayerPoseService();
  final PaceMonitor _paceMonitor = PaceMonitor();
  RepDetector? _repDetector;
  RepDetector? _player1RepDetector;
  RepDetector? _player2RepDetector;

  // Game layer
  FitFusionGame? _game;
  GameController? _gameController;
  final AchievementService _achievementService = AchievementService();

  bool _isInit = false;
  bool _initialized = false;
  String? _error;
  bool _permissionDenied = false;
  bool _sessionEnded = false;
  bool _isSaving = false;
  bool _isDisposed = false;
  Future<void>? _shutdownRealtimePipelineFuture;

  WorkoutType _workoutType = WorkoutType.squats;
  int _cooldownSeconds = kCooldownSeconds;
  double _paceIntervalSeconds = 4.0;
  GameLaunchArgs? _launchArgs;

  bool get _isMultiplayer => _launchArgs?.isMultiplayer == true;

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
      _parseLaunchArgs(args);
      _initAll();
      _isInit = true;
    }
  }

  void _parseLaunchArgs(Object? args) {
    if (args is GameLaunchArgs) {
      _launchArgs = args;
      _workoutType = args.workoutType;
      _cooldownSeconds = args.cooldownSeconds;
    } else if (args is WorkoutType) {
      _workoutType = args;
      _cooldownSeconds = kCooldownSeconds;
      _launchArgs = GameLaunchArgs(
        workoutType: _workoutType,
        cooldownSeconds: _cooldownSeconds,
        bonusRoundsEnabled: false,
      );
    } else {
      _launchArgs = GameLaunchArgs(
        workoutType: _workoutType,
        cooldownSeconds: _cooldownSeconds,
        bonusRoundsEnabled: false,
      );
    }

    if (_launchArgs?.isMultiplayer == true &&
        _workoutType != WorkoutType.jumpingJacks) {
      _workoutType = WorkoutType.jumpingJacks;
      _launchArgs = GameLaunchArgs(
        workoutType: _workoutType,
        cooldownSeconds: _cooldownSeconds,
        isMultiplayer: true,
        player2UserId: _launchArgs?.player2UserId,
        player2Email: _launchArgs?.player2Email,
        bonusRoundsEnabled: false,
      );
    } else if (_launchArgs?.isMultiplayer == true &&
        _launchArgs?.bonusRoundsEnabled == true) {
      _launchArgs = GameLaunchArgs(
        workoutType: _workoutType,
        cooldownSeconds: _cooldownSeconds,
        isMultiplayer: true,
        player2UserId: _launchArgs?.player2UserId,
        player2Email: _launchArgs?.player2Email,
        bonusRoundsEnabled: false,
      );
    }

    _paceIntervalSeconds = _paceIntervalForWorkout(_workoutType);
  }

  double _paceIntervalForWorkout(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:
        return 4.0;
      case WorkoutType.jumpingJacks:
        return 3.0;
      case WorkoutType.obliqueCrunches:
        return 2.0;
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
      if (_isDisposed || !mounted) return;

      await _achievementService.init();
      if (_isDisposed || !mounted) return;

      await AppBgmService.instance.loadGameplayAudio();
      if (_isDisposed || !mounted) return;

      await _cameraService.initialize();
      if (_isDisposed || !mounted) return;

      if (_cameraService.cameraDescription != null) {
        if (_isMultiplayer) {
          _multiplayerPoseDetectorService.startProcessing(
            _cameraService.frameStream,
            _cameraService.cameraDescription!,
          );
          _player1RepDetector = RepDetector(
            workoutType: WorkoutType.jumpingJacks,
            poseStream: _multiplayerPoseDetectorService.player1PoseStream,
            lenientJumpingJacks: true,
          );
          _player2RepDetector = RepDetector(
            workoutType: WorkoutType.jumpingJacks,
            poseStream: _multiplayerPoseDetectorService.player2PoseStream,
            lenientJumpingJacks: true,
          );
        } else {
          _poseDetectorService.startProcessing(
            _cameraService.frameStream,
            _cameraService.cameraDescription!,
          );
          _repDetector = RepDetector(
            workoutType: _workoutType,
            poseStream: _poseDetectorService.poseStream,
          );
        }
      }

      // Create Flame game — configure() before attaching to GameWidget
      _game = FitFusionGame(onSessionComplete: _onSessionComplete);
      _game!.configure(
        workoutType: _workoutType,
        cooldownSeconds: _cooldownSeconds,
        paceIntervalSeconds: _paceIntervalSeconds,
        launchArgs: _launchArgs!,
      );
      _paceMonitor.configure(paceIntervalSeconds: _paceIntervalSeconds);

      // Create GameController bridge
      if (_repDetector != null ||
          (_player1RepDetector != null && _player2RepDetector != null)) {
        _gameController = GameController(
          game: _game!,
          setPoseDetectionEnabled: _setPoseDetectionEnabled,
          paceMonitor: _paceMonitor,
          achievementService: _achievementService,
          repDetector: _repDetector,
          player1RepDetector: _player1RepDetector,
          player2RepDetector: _player2RepDetector,
          isMultiplayer: _isMultiplayer,
          bonusPoseStream: _isMultiplayer
              ? null
              : _poseDetectorService.poseStream,
          bonusPoseMapper: _bonusPoseSnapshotForPose,
        );
      }

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (!_isDisposed && mounted) setState(() => _error = e.toString());
    }
  }

  void _onSessionComplete(GameSession session) {
    if (_sessionEnded) return;
    _sessionEnded = true;
    unawaited(_saveAndNavigate(session));
  }

  Future<void> _saveAndNavigate(GameSession session) async {
    // Show saving indicator
    if (mounted) setState(() => _isSaving = true);

    await _shutdownRealtimePipeline();
    if (mounted) setState(() {});

    // 1. Save session to Supabase
    bool saved = false;
    while (!saved) {
      try {
        await SessionService.saveSession(session);
        saved = true;
      } on SessionSaveException catch (e) {
        assert(() {
          debugPrint('[GameScreen] Session save failed: $e');
          return true;
        }());
        // Show retry dialog
        final retry = await _showSaveErrorDialog();
        if (!retry) {
          // User chose to skip — navigate without saving
          if (mounted) setState(() => _isSaving = false);
          _navigateToResults(session);
          return;
        }
      }
    }

    unawaited(SessionService.trySaveMultiplayerPlayer2Session(session));

    if (mounted) setState(() => _isSaving = false);

    // Stamp the Knight session timestamp (only counts if rounds >= 3) and
    // refresh the upcoming week of scheduled pings so the projected
    // disposition reflects this fresh activity.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await KnightService.markSessionCompleted(userId, session.roundsCompleted);
      // ignore: unawaited_futures
      NotificationService.instance.rescheduleKnightPings(userId);
    }

    // 2. Evaluate achievements against session + lifetime stats views
    final newlyUnlocked = await _achievementService.evaluateSession(session);

    // 3. Show achievement popups
    if (newlyUnlocked.isNotEmpty && _game != null) {
      for (final _ in newlyUnlocked) {
        _game!.showAchievementPopup();
      }
      // Delay navigation so popups are visible (3s popup duration + buffer)
      await Future.delayed(const Duration(milliseconds: 3500));
    }

    // 4. Navigate to results
    _navigateToResults(session);
  }

  Future<bool> _showSaveErrorDialog() async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bloodRed,
        title: const Text(
          'Save Failed',
          style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Could not save your session. Check your connection and try again.',
          style: TextStyle(color: AppTheme.creamWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Skip',
              style: TextStyle(color: AppTheme.creamWhite),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retry', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _navigateToResults(GameSession session) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/results', arguments: session);
  }

  void _onBackPressed() {
    if (_sessionEnded) return;
    _game?.forceDefeat();
  }

  Future<void> _shutdownRealtimePipeline() {
    _shutdownRealtimePipelineFuture ??= _shutdownRealtimePipelineInternal();
    return _shutdownRealtimePipelineFuture!;
  }

  Future<void> _shutdownRealtimePipelineInternal() async {
    final gameController = _gameController;
    final repDetector = _repDetector;
    final player1RepDetector = _player1RepDetector;
    final player2RepDetector = _player2RepDetector;
    _gameController = null;
    _repDetector = null;
    _player1RepDetector = null;
    _player2RepDetector = null;

    _poseDetectorService.setEnabled(false);
    _multiplayerPoseDetectorService.setEnabled(false);
    repDetector?.setEnabled(false);
    player1RepDetector?.setEnabled(false);
    player2RepDetector?.setEnabled(false);
    _paceMonitor.stopMonitoring();

    await _shutdownStep('game controller', () async {
      await gameController?.dispose();
    });
    await _shutdownStep('pace monitor', _paceMonitor.dispose);
    await _shutdownStep('rep detector', () async {
      await repDetector?.dispose();
    });
    await _shutdownStep('player 1 rep detector', () async {
      await player1RepDetector?.dispose();
    });
    await _shutdownStep('player 2 rep detector', () async {
      await player2RepDetector?.dispose();
    });
    await _shutdownStep('pose detector', _poseDetectorService.dispose);
    await _shutdownStep(
      'multiplayer pose detector',
      _multiplayerPoseDetectorService.dispose,
    );
    await _shutdownStep('camera', _cameraService.dispose);
  }

  void _setPoseDetectionEnabled(bool enabled) {
    if (_isMultiplayer) {
      _multiplayerPoseDetectorService.setEnabled(enabled);
    } else {
      _poseDetectorService.setEnabled(enabled);
    }
  }

  BonusPoseSnapshot? _bonusPoseSnapshotForPose(Pose pose) {
    final wrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final previewSize = _cameraService.controller?.value.previewSize;
    final gameSize = _game?.size;
    if (wrist == null || previewSize == null || gameSize == null) return null;
    if (wrist.likelihood < kLandmarkLikelihoodThreshold) return null;

    final canvasSize = Size(gameSize.x, gameSize.y);
    Offset mapLandmark(PoseLandmark landmark) {
      return transformPosePointToScreen(
        x: landmark.x,
        y: landmark.y,
        inputImageSize: previewSize,
        canvasSize: canvasSize,
        lensDirection: _cameraService.lensDirection,
        sensorOrientation: _cameraService.sensorOrientation,
      );
    }

    final bodyPoints = <Offset>[];
    for (final type in const [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ]) {
      final landmark = pose.landmarks[type];
      if (landmark == null ||
          landmark.likelihood < kLandmarkLikelihoodThreshold) {
        continue;
      }
      bodyPoints.add(mapLandmark(landmark));
    }

    if (bodyPoints.length < 4) return null;

    final bodyCenter =
        bodyPoints.reduce((a, b) => a + b) / bodyPoints.length.toDouble();
    var bodyRadius = 0.0;
    for (final point in bodyPoints) {
      bodyRadius = math.max(bodyRadius, (point - bodyCenter).distance);
    }

    return BonusPoseSnapshot(
      handPosition: mapLandmark(wrist),
      bodyCenter: bodyCenter,
      bodyRadius: bodyRadius + 48,
    );
  }

  Future<void> _shutdownStep(
    String label,
    Future<void> Function() dispose,
  ) async {
    try {
      await dispose();
    } catch (e) {
      assert(() {
        debugPrint('[GameScreen] Failed to dispose $label: $e');
        return true;
      }());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_shutdownRealtimePipeline());
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
                const Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.crimson,
                  size: 64,
                ),
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
                    backgroundColor: AppTheme.gold,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: AppTheme.bloodRed),
                  ),
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
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: AppTheme.crimson),
          ),
        ),
      );
    }

    if (!_initialized || _game == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bloodRed,
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
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

            if (_isMultiplayer) const _MultiplayerLaneOverlay(),

            // Layer 2: Pose skeleton overlay (debug only)
            if (kDebugMode)
              _isMultiplayer
                  ? StreamBuilder<MultiplayerPoses>(
                      stream:
                          _multiplayerPoseDetectorService.multiplayerPoseStream,
                      builder: (context, snapshot) {
                        final poses = snapshot.data;
                        if (_cameraService.controller?.value.previewSize ==
                                null ||
                            poses == null) {
                          return const SizedBox.shrink();
                        }
                        return MultiplayerPoseOverlayWidget(
                          player1Pose: poses.player1,
                          player2Pose: poses.player2,
                          inputImageSize:
                              _cameraService.controller!.value.previewSize!,
                          lensDirection: _cameraService.lensDirection,
                          sensorOrientation: _cameraService.sensorOrientation,
                        );
                      },
                    )
                  : StreamBuilder<Pose?>(
                      stream: _poseDetectorService.poseStream,
                      builder: (context, snapshot) {
                        final pose = snapshot.data;
                        if (_cameraService.controller?.value.previewSize ==
                            null) {
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

            // Layer 4: Saving overlay
            if (_isSaving)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.gold),
                      SizedBox(height: 16),
                      Text(
                        'Saving...',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MultiplayerLaneOverlay extends StatelessWidget {
  const _MultiplayerLaneOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.08),
                    border: Border(
                      right: BorderSide(
                        color: AppTheme.gold.withValues(alpha: 0.75),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: AppTheme.crimson.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          Align(
            alignment: const Alignment(-0.82, -0.12),
            child: _LaneLabel(text: 'P1'),
          ),
          Align(
            alignment: const Alignment(0.82, -0.12),
            child: _LaneLabel(text: 'P2'),
          ),
        ],
      ),
    );
  }
}

class _LaneLabel extends StatelessWidget {
  final String text;

  const _LaneLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        border: Border.all(color: AppTheme.gold, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.gold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
      ),
    );
  }
}
