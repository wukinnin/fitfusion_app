import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/enums.dart';
import '../../core/events.dart';
import '../achievements/achievement_service.dart';
import '../motion/pace_monitor.dart';
import '../motion/rep_detector.dart';
import 'fitfusion_game.dart';

/// Bridge layer between the motion pipeline and the Flame game.
/// Subscribes to RepDetector and PaceMonitor streams, translates
/// events into game actions, and manages pace monitoring lifecycle.
/// Also evaluates achievements at session end.
class GameController {
  static const Duration multiplayerRepSyncWindow = Duration(milliseconds: 750);

  final FitFusionGame game;
  final RepDetector? repDetector;
  final RepDetector? player1RepDetector;
  final RepDetector? player2RepDetector;
  final void Function(bool enabled) setPoseDetectionEnabled;
  final PaceMonitor paceMonitor;
  final AchievementService achievementService;
  final bool isMultiplayer;

  StreamSubscription<RepEvent>? _repSubscription;
  StreamSubscription<RepEvent>? _player1RepSubscription;
  StreamSubscription<RepEvent>? _player2RepSubscription;
  StreamSubscription<PaceEvent>? _paceSubscription;
  StreamSubscription<GamePhase>? _phaseSubscription;
  Timer? _pendingRepTimer;
  DateTime? _pendingPlayer1RepAt;
  DateTime? _pendingPlayer2RepAt;
  Future<void>? _disposeFuture;

  GameController({
    required this.game,
    required this.setPoseDetectionEnabled,
    required this.paceMonitor,
    required this.achievementService,
    this.repDetector,
    this.player1RepDetector,
    this.player2RepDetector,
    this.isMultiplayer = false,
  }) {
    _wireStreams();
  }

  void _wireStreams() {
    // Rep events → game
    if (isMultiplayer) {
      _player1RepSubscription = player1RepDetector?.repStream.listen((event) {
        _onMultiplayerRep(player: 1, timestamp: event.timestamp);
      });
      _player2RepSubscription = player2RepDetector?.repStream.listen((event) {
        _onMultiplayerRep(player: 2, timestamp: event.timestamp);
      });
    } else {
      _repSubscription = repDetector?.repStream.listen((_) {
        if (game.phase == GamePhase.playing) {
          _acceptRep();
        }
      });
    }

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
          setPoseDetectionEnabled(true);
          _setRepDetectorsEnabled(true);
          // Pace timer starts immediately when playing begins.
          paceMonitor.startMonitoring();
          break;
        case GamePhase.cooldown:
          setPoseDetectionEnabled(true);
          _setRepDetectorsEnabled(false);
          _clearPendingMultiplayerReps();
          paceMonitor.stopMonitoring();
          break;
        case GamePhase.victory:
        case GamePhase.defeat:
          setPoseDetectionEnabled(false);
          _setRepDetectorsEnabled(false);
          _clearPendingMultiplayerReps();
          paceMonitor.stopMonitoring();
          break;
      }
    });
  }

  void _onMultiplayerRep({required int player, required DateTime timestamp}) {
    if (game.phase != GamePhase.playing) return;

    final partnerRepAt = player == 1
        ? _pendingPlayer2RepAt
        : _pendingPlayer1RepAt;
    if (partnerRepAt != null &&
        (timestamp.difference(partnerRepAt).abs() <=
            multiplayerRepSyncWindow)) {
      _clearPendingMultiplayerReps();
      _acceptRep();
      return;
    }

    if (player == 1) {
      _pendingPlayer1RepAt = timestamp;
    } else {
      _pendingPlayer2RepAt = timestamp;
    }
    _armPendingRepExpiry();
  }

  void _acceptRep() {
    if (paceMonitor.isActive) {
      paceMonitor.onRepReceived();
    } else {
      paceMonitor.startMonitoring();
    }
    game.onRepDetected();
  }

  void _armPendingRepExpiry() {
    _pendingRepTimer?.cancel();
    _pendingRepTimer = Timer(multiplayerRepSyncWindow, () {
      _clearPendingMultiplayerReps();
    });
  }

  void _clearPendingMultiplayerReps() {
    _pendingRepTimer?.cancel();
    _pendingRepTimer = null;
    _pendingPlayer1RepAt = null;
    _pendingPlayer2RepAt = null;
  }

  void _setRepDetectorsEnabled(bool enabled) {
    repDetector?.setEnabled(enabled);
    player1RepDetector?.setEnabled(enabled);
    player2RepDetector?.setEnabled(enabled);
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeInternal();
    await _disposeFuture;
  }

  Future<void> _disposeInternal() async {
    final repSubscription = _repSubscription;
    final player1RepSubscription = _player1RepSubscription;
    final player2RepSubscription = _player2RepSubscription;
    final paceSubscription = _paceSubscription;
    final phaseSubscription = _phaseSubscription;
    _repSubscription = null;
    _player1RepSubscription = null;
    _player2RepSubscription = null;
    _paceSubscription = null;
    _phaseSubscription = null;
    _clearPendingMultiplayerReps();

    await repSubscription?.cancel();
    await player1RepSubscription?.cancel();
    await player2RepSubscription?.cancel();
    await paceSubscription?.cancel();
    await phaseSubscription?.cancel();
    assert(() {
      debugPrint('[GameController] Disposed');
      return true;
    }());
  }
}
