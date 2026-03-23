import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/enums.dart';
import '../achievements/achievement_service.dart';
import '../motion/pace_monitor.dart';
import '../motion/rep_detector.dart';
import 'fitfusion_game.dart';

/// Bridge layer between the motion pipeline and the Flame game.
/// Subscribes to RepDetector and PaceMonitor streams, translates
/// events into game actions, and manages pace monitoring lifecycle.
/// Also evaluates achievements at session end.
class GameController {
  final FitFusionGame game;
  final RepDetector repDetector;
  final PaceMonitor paceMonitor;
  final AchievementService achievementService;

  StreamSubscription<void>? _repSubscription;
  StreamSubscription<void>? _paceSubscription;
  StreamSubscription<GamePhase>? _phaseSubscription;

  GameController({
    required this.game,
    required this.repDetector,
    required this.paceMonitor,
    required this.achievementService,
  }) {
    _wireStreams();
  }

  void _wireStreams() {
    // Rep events → game
    _repSubscription = repDetector.repStream.listen((_) {
      if (game.phase == GamePhase.playing) {
        paceMonitor.onRepReceived();
        game.onRepDetected();
      }
    });

    // Pace events → game
    _paceSubscription = paceMonitor.paceStream.listen((event) {
      if (event.type == PaceEventType.paceFailed &&
          game.phase == GamePhase.playing) {
        game.onPaceFailed();
      }
    });

    // Phase changes → manage pace monitor lifecycle
    _phaseSubscription = game.phaseStream.listen((phase) {
      switch (phase) {
        case GamePhase.playing:
          // Pace timer starts immediately when playing begins
          paceMonitor.startMonitoring();
          break;
        case GamePhase.cooldown:
        case GamePhase.victory:
        case GamePhase.defeat:
          paceMonitor.stopMonitoring();
          break;
      }
    });
  }

  Future<void> dispose() async {
    await _repSubscription?.cancel();
    await _paceSubscription?.cancel();
    await _phaseSubscription?.cancel();
    debugPrint('[GameController] Disposed');
  }
}
