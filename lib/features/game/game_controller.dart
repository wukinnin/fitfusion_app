import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
  static const Duration multiplayerRepSyncWindow = Duration(milliseconds: 1200);
  static const Duration multiplayerPhaseUpSyncWindow = Duration(
    milliseconds: 1500,
  );
  static const Duration multiplayerPhaseDownSyncWindow = Duration(
    milliseconds: 1800,
  );
  static const Duration multiplayerPhaseSyncTimeout = Duration(
    milliseconds: 3500,
  );
  static const Duration multiplayerDuplicateRepGuard = Duration(
    milliseconds: 650,
  );

  final FitFusionGame game;
  final RepDetector? repDetector;
  final RepDetector? player1RepDetector;
  final RepDetector? player2RepDetector;
  final void Function(bool enabled) setPoseDetectionEnabled;
  final Stream<Pose?>? bonusPoseStream;
  final BonusPoseSnapshot? Function(Pose pose)? bonusPoseMapper;
  final PaceMonitor paceMonitor;
  final AchievementService achievementService;
  final bool isMultiplayer;

  StreamSubscription<RepEvent>? _repSubscription;
  StreamSubscription<RepEvent>? _player1RepSubscription;
  StreamSubscription<RepEvent>? _player2RepSubscription;
  StreamSubscription<JumpingJackPhaseEvent>? _player1PhaseSubscription;
  StreamSubscription<JumpingJackPhaseEvent>? _player2PhaseSubscription;
  StreamSubscription<Pose?>? _bonusPoseSubscription;
  StreamSubscription<PaceEvent>? _paceSubscription;
  StreamSubscription<GamePhase>? _phaseSubscription;
  Timer? _pendingRepTimer;
  Timer? _phaseSyncTimer;
  DateTime? _pendingPlayer1RepAt;
  DateTime? _pendingPlayer2RepAt;
  DateTime? _player1UpAt;
  DateTime? _player2UpAt;
  DateTime? _player1DownAt;
  DateTime? _player2DownAt;
  DateTime? _lastAcceptedMultiplayerRepAt;
  bool _awaitingMultiplayerDownPhase = false;
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
    this.bonusPoseStream,
    this.bonusPoseMapper,
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
      _player1PhaseSubscription = player1RepDetector?.jumpingJackPhaseStream
          .listen((event) {
            _onMultiplayerJumpingJackPhase(player: 1, event: event);
          });
      _player2PhaseSubscription = player2RepDetector?.jumpingJackPhaseStream
          .listen((event) {
            _onMultiplayerJumpingJackPhase(player: 2, event: event);
          });
    } else {
      _repSubscription = repDetector?.repStream.listen((_) {
        if (game.phase == GamePhase.playing) {
          _acceptRep();
        }
      });
    }

    _bonusPoseSubscription = bonusPoseStream?.listen((pose) {
      if (pose == null || game.phase != GamePhase.bonusPlaying) return;
      final snapshot = bonusPoseMapper?.call(pose);
      if (snapshot != null) {
        game.onBonusPose(snapshot);
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
          setPoseDetectionEnabled(true);
          _setRepDetectorsEnabled(true);
          // Pace timer starts immediately when playing begins.
          paceMonitor.startMonitoring();
          break;
        case GamePhase.cooldown:
        case GamePhase.bonusCooldown:
          setPoseDetectionEnabled(true);
          _setRepDetectorsEnabled(false);
          _clearMultiplayerSyncState();
          paceMonitor.stopMonitoring();
          break;
        case GamePhase.bonusPlaying:
          setPoseDetectionEnabled(true);
          _setRepDetectorsEnabled(false);
          _clearMultiplayerSyncState();
          paceMonitor.stopMonitoring();
          break;
        case GamePhase.victory:
        case GamePhase.defeat:
          setPoseDetectionEnabled(false);
          _setRepDetectorsEnabled(false);
          _clearMultiplayerSyncState();
          paceMonitor.stopMonitoring();
          break;
      }
    });
  }

  void _onMultiplayerRep({required int player, required DateTime timestamp}) {
    if (game.phase != GamePhase.playing) return;
    if (_isDuplicateMultiplayerRep(timestamp)) return;

    final partnerRepAt = player == 1
        ? _pendingPlayer2RepAt
        : _pendingPlayer1RepAt;
    if (partnerRepAt != null &&
        (timestamp.difference(partnerRepAt).abs() <=
            multiplayerRepSyncWindow)) {
      _acceptSharedMultiplayerRep(reason: 'completed-rep fallback');
      return;
    }

    if (player == 1) {
      _pendingPlayer1RepAt = timestamp;
    } else {
      _pendingPlayer2RepAt = timestamp;
    }
    _armPendingRepExpiry();
  }

  void _onMultiplayerJumpingJackPhase({
    required int player,
    required JumpingJackPhaseEvent event,
  }) {
    if (game.phase != GamePhase.playing) return;
    if (_isDuplicateMultiplayerRep(event.timestamp)) return;

    switch (event.phase) {
      case JumpingJackPhase.up:
        _onMultiplayerUpPhase(player: player, timestamp: event.timestamp);
        break;
      case JumpingJackPhase.down:
        _onMultiplayerDownPhase(player: player, timestamp: event.timestamp);
        break;
    }
  }

  void _onMultiplayerUpPhase({
    required int player,
    required DateTime timestamp,
  }) {
    if (_awaitingMultiplayerDownPhase) {
      _resetMultiplayerPhaseSync(
        reason: 'new up before pair returned down',
        keepPlayer: player,
        keepUpAt: timestamp,
      );
      return;
    }

    if (player == 1) {
      _player1UpAt = timestamp;
    } else {
      _player2UpAt = timestamp;
    }

    final p1UpAt = _player1UpAt;
    final p2UpAt = _player2UpAt;
    if (p1UpAt != null && p2UpAt != null) {
      final inSync =
          p1UpAt.difference(p2UpAt).abs() <= multiplayerPhaseUpSyncWindow;
      if (inSync) {
        _awaitingMultiplayerDownPhase = true;
        _player1DownAt = null;
        _player2DownAt = null;
        _debugMultiplayerSync('phase up synced p1:$p1UpAt p2:$p2UpAt');
      } else if (p1UpAt.isAfter(p2UpAt)) {
        _player2UpAt = null;
        _debugMultiplayerSync('expired P2 up: missed up sync window');
      } else {
        _player1UpAt = null;
        _debugMultiplayerSync('expired P1 up: missed up sync window');
      }
    }

    _armPhaseSyncExpiry();
  }

  void _onMultiplayerDownPhase({
    required int player,
    required DateTime timestamp,
  }) {
    if (!_awaitingMultiplayerDownPhase) return;

    final playerUpAt = player == 1 ? _player1UpAt : _player2UpAt;
    if (playerUpAt == null || timestamp.isBefore(playerUpAt)) return;

    if (player == 1) {
      _player1DownAt = timestamp;
    } else {
      _player2DownAt = timestamp;
    }

    final p1DownAt = _player1DownAt;
    final p2DownAt = _player2DownAt;
    if (p1DownAt != null && p2DownAt != null) {
      final inSync =
          p1DownAt.difference(p2DownAt).abs() <= multiplayerPhaseDownSyncWindow;
      if (inSync) {
        _acceptSharedMultiplayerRep(reason: 'phase sync');
      } else {
        _resetMultiplayerPhaseSync(reason: 'missed down sync window');
      }
      return;
    }

    _armPhaseSyncExpiry();
  }

  bool _isDuplicateMultiplayerRep(DateTime timestamp) {
    final lastAcceptedAt = _lastAcceptedMultiplayerRepAt;
    return lastAcceptedAt != null &&
        timestamp.difference(lastAcceptedAt).abs() <=
            multiplayerDuplicateRepGuard;
  }

  void _acceptSharedMultiplayerRep({required String reason}) {
    _lastAcceptedMultiplayerRepAt = DateTime.now();
    _debugMultiplayerSync('accepted shared rep: $reason');
    _clearMultiplayerSyncState();
    _acceptRep();
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

  void _armPhaseSyncExpiry() {
    _phaseSyncTimer?.cancel();
    _phaseSyncTimer = Timer(multiplayerPhaseSyncTimeout, () {
      _resetMultiplayerPhaseSync(reason: 'phase sync timeout');
    });
  }

  void _clearPendingMultiplayerReps() {
    _pendingRepTimer?.cancel();
    _pendingRepTimer = null;
    _pendingPlayer1RepAt = null;
    _pendingPlayer2RepAt = null;
  }

  void _clearMultiplayerPhaseSync() {
    _player1UpAt = null;
    _player2UpAt = null;
    _player1DownAt = null;
    _player2DownAt = null;
    _awaitingMultiplayerDownPhase = false;
  }

  void _clearMultiplayerSyncState() {
    _clearPendingMultiplayerReps();
    _phaseSyncTimer?.cancel();
    _phaseSyncTimer = null;
    _clearMultiplayerPhaseSync();
  }

  void _resetMultiplayerPhaseSync({
    required String reason,
    int? keepPlayer,
    DateTime? keepUpAt,
  }) {
    _debugMultiplayerSync('reset phase sync: $reason');
    _phaseSyncTimer?.cancel();
    _phaseSyncTimer = null;
    _clearMultiplayerPhaseSync();
    if (keepPlayer != null && keepUpAt != null) {
      if (keepPlayer == 1) {
        _player1UpAt = keepUpAt;
      } else {
        _player2UpAt = keepUpAt;
      }
      _armPhaseSyncExpiry();
    }
  }

  void _debugMultiplayerSync(String message) {
    assert(() {
      debugPrint('[GameController][MP Sync] $message');
      return true;
    }());
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
    final player1PhaseSubscription = _player1PhaseSubscription;
    final player2PhaseSubscription = _player2PhaseSubscription;
    final bonusPoseSubscription = _bonusPoseSubscription;
    final paceSubscription = _paceSubscription;
    final phaseSubscription = _phaseSubscription;
    _repSubscription = null;
    _player1RepSubscription = null;
    _player2RepSubscription = null;
    _player1PhaseSubscription = null;
    _player2PhaseSubscription = null;
    _bonusPoseSubscription = null;
    _paceSubscription = null;
    _phaseSubscription = null;
    _clearMultiplayerSyncState();

    await repSubscription?.cancel();
    await player1RepSubscription?.cancel();
    await player2RepSubscription?.cancel();
    await player1PhaseSubscription?.cancel();
    await player2PhaseSubscription?.cancel();
    await bonusPoseSubscription?.cancel();
    await paceSubscription?.cancel();
    await phaseSubscription?.cancel();
    assert(() {
      debugPrint('[GameController] Disposed');
      return true;
    }());
  }
}
