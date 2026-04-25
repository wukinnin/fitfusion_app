import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart' hide Timer;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/extensions.dart';
import '../../services/app_bgm_service.dart';
import 'components/achievement_popup.dart';
import 'components/cooldown_overlay.dart';
import 'components/damage_flash_overlay.dart';
import 'components/damage_number.dart';
import 'components/monster_component.dart';
import 'components/monster_health_bar.dart';
import 'components/pace_timer_indicator.dart';
import 'components/player_lives_display.dart';
import 'components/rep_progress_bar.dart';
import 'components/round_banner.dart';
import 'components/sword_slash_component.dart';
import 'game_session.dart';

/// The core Flame game engine for FitFusion.
/// Manages game state, rounds, lives, and session data.
/// Driven by external GameController calls (onRepDetected, onPaceFailed).
class FitFusionGame extends FlameGame {
  final void Function(GameSession session) onSessionComplete;

  FitFusionGame({required this.onSessionComplete});

  // --- State & Streams ---

  final StreamController<GamePhase> _phaseController =
      StreamController<GamePhase>.broadcast();
  Stream<GamePhase> get phaseStream => _phaseController.stream;

  GamePhase _phase = GamePhase.cooldown;
  GamePhase get phase => _phase;

  // Session Config
  WorkoutType _workoutType = WorkoutType.squats;
  WorkoutType get workoutType => _workoutType;

  // Game Progress
  int _currentRound = 1;
  int get currentRound => _currentRound;
  int _monsterHP = 0;
  int _monsterMaxHP = 0;
  int _playerLives = kStartingLives;

  // Session Stats
  int _totalReps = 0;
  int _livesLost = 0;
  int _roundsCompleted = 0;
  DateTime? _sessionStartTime;

  // Interval tracking — same-round consecutive reps only
  final List<double> _repIntervals = [];
  DateTime? _lastRepTime;
  int _lastRepRound = 0;

  // Pace timer tracking
  double _paceTimeRemaining = kPaceThresholdSeconds;
  bool _paceTimerActive = false;

  // Post-round-win delay — let hit effects play before cooldown
  static const double _roundWinDelay = 1;
  bool _waitingForRoundWinDelay = false;
  double _roundWinDelayTimer = 0;
  bool _roundWinIsVictory = false;

  // --- Components ---
  late final MonsterComponent _monster;
  late final MonsterHealthBar _healthBar;
  late final RepProgressBar _repProgress;
  late final PaceTimerIndicator _paceIndicator;
  late final PlayerLivesDisplay _livesDisplay;
  late final RoundBanner _roundBanner;
  late final CooldownOverlay _cooldownOverlay;
  late final DamageFlashOverlay _damageFlash;
  final List<SwordSlashComponent> _slashPool = [];
  final List<DamageNumber> _damageNumberPool = [];

  // HUD components — slide in/out with cooldown
  final List<PositionComponent> _hudComponents = [];
  // Store original X positions so we can offset them during slide
  final Map<PositionComponent, double> _hudOriginalX = {};

  bool _sessionEnded = false;

  // --- Lifecycle & Config ---

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.loadAll([
      ...MonsterComponent.monsterFiles,
      'game/squats.png',
      'game/jumping-jacks.png',
      'game/side-crunches.png',
    ]);

    // === TOP HUD LAYOUT ===
    // Row 1: Health bar — full width, near top
    const topY = 36.0;
    _healthBar = MonsterHealthBar()..position = Vector2(12, topY);
    add(_healthBar);

    // Row 2: Monster (left) | Rep counter (center) | Pace timer (right)
    const row2Y = topY + MonsterHealthBar.barHeight + 8;

    _monster = MonsterComponent()..position = Vector2(8, row2Y);
    add(_monster);

    _repProgress = RepProgressBar()
      ..position = Vector2(MonsterComponent.displayWidth + 16, row2Y + 4);
    add(_repProgress);

    _paceIndicator = PaceTimerIndicator()
      ..position = Vector2(size.x - PaceTimerIndicator.radius * 2 - 12, row2Y);
    add(_paceIndicator);

    // === BOTTOM HUD LAYOUT (centered) ===
    _roundBanner = RoundBanner()..position = Vector2(0, size.y - 130);
    add(_roundBanner);

    _livesDisplay = PlayerLivesDisplay()
      ..position = Vector2(
        (size.x - PlayerLivesDisplay.totalWidth) / 2,
        size.y - 80,
      );
    add(_livesDisplay);

    // === OVERLAYS ===
    _damageFlash = DamageFlashOverlay();
    add(_damageFlash);

    _cooldownOverlay = CooldownOverlay()
      ..onCooldownComplete = _onCooldownComplete;
    add(_cooldownOverlay);

    for (var i = 0; i < 6; i++) {
      final slash = SwordSlashComponent();
      _slashPool.add(slash);
      add(slash);

      final damageNumber = DamageNumber();
      _damageNumberPool.add(damageNumber);
      add(damageNumber);
    }

    // Track all HUD components for slide animation during cooldown
    _hudComponents.addAll([
      _monster,
      _healthBar,
      _repProgress,
      _paceIndicator,
      _roundBanner,
      _livesDisplay,
    ]);
    // Store their original X positions
    for (final comp in _hudComponents) {
      _hudOriginalX[comp] = comp.position.x;
    }

    // All components ready — start the session with initial cooldown
    _resetGame();
  }

  /// Called by GameScreen/GameController before the game session starts.
  /// Must be called BEFORE the game is attached to a GameWidget.
  void configure({required WorkoutType workoutType}) {
    _workoutType = workoutType;
  }

  void _resetGame() {
    _sessionEnded = false;
    _currentRound = 1;
    _monsterMaxHP = repsRequiredForRound(1);
    _monsterHP = _monsterMaxHP;
    _playerLives = kStartingLives;

    _totalReps = 0;
    _livesLost = 0;
    _roundsCompleted = 0;
    _sessionStartTime = DateTime.now();
    _repIntervals.clear();
    _lastRepTime = null;
    _lastRepRound = 0;

    _paceTimeRemaining = kPaceThresholdSeconds;
    _paceTimerActive = false;

    // Update all components
    _updateHUD();

    // Start initial cooldown for Round 1
    _enterCooldown();
  }

  void _updateHUD() {
    _healthBar.setHP(_monsterHP, _monsterMaxHP);
    _repProgress.setProgress(_monsterMaxHP - _monsterHP, _monsterMaxHP);
    _livesDisplay.setLives(_playerLives);
    _roundBanner.setRound(_currentRound);
    _roundBanner.setWorkoutLabel(_workoutType.displayName.toUpperCase());
    _paceIndicator.setRemaining(_paceTimeRemaining);
  }

  void _slideHUDWithCooldown() {
    if (!_cooldownOverlay.isActive) {
      // Restore all HUD to original positions
      for (final comp in _hudComponents) {
        comp.position.x = _hudOriginalX[comp] ?? comp.position.x;
      }
      return;
    }

    final fraction = _cooldownOverlay.slideOffsetFraction;
    final double offsetX;

    if (fraction <= 0) {
      // During cooldown entry/countdown, keep HUD off-screen to the left
      offsetX = -size.x;
    } else {
      // As cooldown slides out, bring HUD in from the left concurrently
      offsetX = -size.x * (1 - fraction);
    }

    for (final comp in _hudComponents) {
      final origX = _hudOriginalX[comp] ?? 0;
      comp.position.x = origX + offsetX;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Pace timer countdown during playing phase
    if (_phase == GamePhase.playing && _paceTimerActive) {
      _paceTimeRemaining -= dt;
      _paceIndicator.setRemaining(_paceTimeRemaining);
    }

    // Post-round-win delay before cooldown transition
    if (_waitingForRoundWinDelay) {
      _roundWinDelayTimer += dt;
      if (_roundWinDelayTimer >= _roundWinDelay) {
        _completeRoundWinTransition();
      }
    }

    // Slide HUD elements in sync with cooldown overlay
    _slideHUDWithCooldown();
  }

  @override
  void onRemove() {
    for (final timer in _popupTimers) {
      timer.cancel();
    }
    _popupTimers.clear();
    _slashPool.clear();
    _damageNumberPool.clear();
    _hudComponents.clear();
    _hudOriginalX.clear();
    _repIntervals.clear();
    _activePopupCount = 0;
    _waitingForRoundWinDelay = false;
    _paceTimerActive = false;

    if (!_phaseController.isClosed) {
      _phaseController.close();
    }
    super.onRemove();
  }

  // --- External API (Called by GameController) ---

  void onRepDetected() {
    if (_phase != GamePhase.playing) return;

    _handleRep();
  }

  void onPaceFailed() {
    if (_phase != GamePhase.playing) return;

    _handlePaceFailure();
  }

  /// Force an immediate defeat (e.g. back button press, app paused).
  void forceDefeat() {
    if (_sessionEnded) return;
    if (_phase == GamePhase.victory || _phase == GamePhase.defeat) return;

    _playerLives = 0;
    _livesDisplay.setLives(0);
    _cooldownOverlay.stopCooldown();
    _handleDefeat();
  }

  // --- Phase Management ---

  void _enterCooldown() {
    _phase = GamePhase.cooldown;
    _phaseController.add(_phase);

    _paceTimerActive = false;
    _paceIndicator.setActive(false);

    _cooldownOverlay.startCooldown(_currentRound);
    _playAudioSafe('sfx/win_violin.mp3');
  }

  void _onCooldownComplete() {
    // Cooldown done — enter playing phase
    _updateHUD();

    _phase = GamePhase.playing;
    _phaseController.add(_phase);

    // Pace timer starts immediately after cooldown.
    _paceTimeRemaining = kPaceThresholdSeconds;
    _paceTimerActive = true;
    _paceIndicator.setActive(true);
  }

  // --- Internal Game Logic ---

  void _handleRep() {
    _monsterHP--;
    _totalReps++;

    // Track interval — only between consecutive reps in the same round
    final now = DateTime.now();
    if (_lastRepTime != null && _lastRepRound == _currentRound) {
      final interval = now.difference(_lastRepTime!).inMilliseconds / 1000.0;
      _repIntervals.add(interval);
    }
    _lastRepTime = now;
    _lastRepRound = _currentRound;

    // Reset pace timer.
    _paceTimeRemaining = kPaceThresholdSeconds;
    _paceIndicator.setRemaining(_paceTimeRemaining);

    // Update visuals
    _healthBar.setHP(_monsterHP, _monsterMaxHP);
    _repProgress.setProgress(_monsterMaxHP - _monsterHP, _monsterMaxHP);

    // Monster hit flash
    _monster.flashHit();

    // Spawn slash + damage number
    _spawnHitEffects();

    // Audio
    _playAudioSafe('sfx/thud.mp3');

    if (_monsterHP <= 0) {
      _handleRoundWon();
    }
  }

  void _spawnHitEffects() {
    final slash = _slashPool.firstWhere(
      (effect) => !effect.isEffectActive,
      orElse: () => _slashPool.first,
    );
    slash.activateAt(
      _monster.position.x +
          MonsterComponent.displayWidth / 2 -
          SwordSlashComponent.slashWidth / 2,
      _monster.position.y +
          MonsterComponent.displayHeight / 2 -
          SwordSlashComponent.slashHeight / 2,
    );

    final damageNumber = _damageNumberPool.firstWhere(
      (effect) => !effect.isEffectActive,
      orElse: () => _damageNumberPool.first,
    );
    damageNumber.activateAt(
      _monster.position.x + MonsterComponent.displayWidth / 2,
      _monster.position.y + 10,
    );
  }

  void _handlePaceFailure() {
    _playerLives--;
    _livesLost++;

    _livesDisplay.setLives(_playerLives);
    _damageFlash.trigger();
    _playAudioSafe('sfx/damage.mp3');

    // Reset pace timer after failure
    _paceTimeRemaining = kPaceThresholdSeconds;
    _paceIndicator.setRemaining(_paceTimeRemaining);

    if (_playerLives <= 0) {
      _handleDefeat();
    }
  }

  void _handleRoundWon() {
    _roundsCompleted++;
    _paceTimerActive = false;
    _paceIndicator.setActive(false);

    // Freeze pace timer display at 5
    _paceTimeRemaining = kPaceThresholdSeconds;
    _paceIndicator.setRemaining(_paceTimeRemaining);

    // Start delay so player sees hit effects, health bar at 0, etc.
    _waitingForRoundWinDelay = true;
    _roundWinDelayTimer = 0;
    _roundWinIsVictory = _currentRound >= kTotalRounds;
  }

  void _completeRoundWinTransition() {
    _waitingForRoundWinDelay = false;

    if (_roundWinIsVictory) {
      _handleVictory();
    } else {
      // Advance round and enter cooldown
      _currentRound++;
      _monsterMaxHP = repsRequiredForRound(_currentRound);
      _monsterHP = _monsterMaxHP;
      _monster.nextMonster();
      _enterCooldown();
    }
  }

  void _handleVictory() {
    _phase = GamePhase.victory;
    _phaseController.add(_phase);
    _finishSession(won: true);
  }

  void _handleDefeat() {
    _paceTimerActive = false;
    _paceIndicator.setActive(false);
    _phase = GamePhase.defeat;
    _phaseController.add(_phase);
    _finishSession(won: false);
  }

  void _finishSession({required bool won}) {
    if (_sessionEnded) return;
    _sessionEnded = true;

    _paceTimerActive = false;
    _cooldownOverlay.stopCooldown();

    final endTime = DateTime.now();
    final startTime = _sessionStartTime ?? endTime;
    final durationSeconds =
        endTime.difference(startTime).inMilliseconds / 1000.0;

    double bestInterval = 0.0;
    double avgInterval = 0.0;

    if (_repIntervals.isNotEmpty) {
      bestInterval = _repIntervals.reduce(min);
      avgInterval =
          _repIntervals.reduce((a, b) => a + b) / _repIntervals.length;
    }

    // Total reps required across all rounds: sum of (round + 1) for rounds 1..10 = 65
    int totalRequired = 0;
    for (int r = 1; r <= kTotalRounds; r++) {
      totalRequired += repsRequiredForRound(r);
    }

    final session = GameSession(
      workoutType: _workoutType,
      won: won,
      totalReps: _totalReps,
      totalRepsRequired: totalRequired,
      totalTimeSeconds: durationSeconds,
      roundsCompleted: _roundsCompleted,
      bestRepIntervalSeconds: bestInterval,
      avgRepIntervalSeconds: avgInterval,
      livesLost: _livesLost,
      completedAt: endTime,
    );

    onSessionComplete(session);
  }

  // --- Achievement Popup ---

  int _activePopupCount = 0;
  final List<Timer> _popupTimers = [];

  /// Spawns an achievement trophy popup below the pace timer.
  /// Each concurrent popup stacks downward via [stackIndex].
  void showAchievementPopup() {
    final stackIndex = _activePopupCount;
    _activePopupCount++;

    final popup = AchievementPopup(stackIndex: stackIndex);
    add(popup);
    _playAudioSafe('sfx/achievement.mp3');

    // Decrement active count when popup finishes (total duration = 3.0s)
    late final Timer popupTimer;
    popupTimer = Timer(const Duration(seconds: 3), () {
      _popupTimers.remove(popupTimer);
      _activePopupCount = (_activePopupCount - 1).clamp(0, 100);
    });
    _popupTimers.add(popupTimer);
  }

  // --- Audio Helper ---

  void _playAudioSafe(String file) {
    unawaited(
      AppBgmService.instance.playSfx(file).catchError((Object e) {
        assert(() {
          debugPrint('[FitFusionGame] Audio error: $e');
          return true;
        }());
      }),
    );
  }
}
