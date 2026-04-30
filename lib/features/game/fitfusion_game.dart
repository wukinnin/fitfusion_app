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
import 'components/bonus_item_component.dart';
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
import 'game_launch_args.dart';
import 'game_session.dart';

enum _CooldownTarget { normalRound, beforeBonus, afterBonus }

class BonusPoseSnapshot {
  final Offset handPosition;
  final Offset bodyCenter;
  final double bodyRadius;

  const BonusPoseSnapshot({
    required this.handPosition,
    required this.bodyCenter,
    required this.bodyRadius,
  });
}

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
  bool get isBonusMode => _phase == GamePhase.bonusPlaying;

  // Session Config
  WorkoutType _workoutType = WorkoutType.squats;
  WorkoutType get workoutType => _workoutType;
  int _cooldownSeconds = kCooldownSeconds;
  int get cooldownSeconds => _cooldownSeconds;
  double _paceIntervalSeconds = kPaceThresholdSeconds;
  double get paceIntervalSeconds => _paceIntervalSeconds;
  GameLaunchArgs _launchArgs = const GameLaunchArgs(
    workoutType: WorkoutType.squats,
    cooldownSeconds: kCooldownSeconds,
  );
  bool _bonusRoundsEnabled = false;

  // Game Progress
  int _currentRound = 1;
  int get currentRound => _currentRound;
  int _monsterHP = 0;
  int _monsterMaxHP = 0;
  int _playerLives = kStartingLives;
  int _dragonLifeSteals = 0;
  int _bonusGemsCollected = 0;
  int _activeBonusNumber = 0;
  double _bonusTimeRemaining = 15;
  double _bonusElapsedTotal = 0;
  double _bonusTargetMoveTimer = 0;
  bool _bonusEnding = false;
  double _bonusEndDelay = 0;
  Offset? _lastBonusSpawnCenter;
  Offset? _lastBonusBodyCenter;
  double _lastBonusBodyRadius = 0;
  _CooldownTarget _cooldownTarget = _CooldownTarget.normalRound;

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
  final List<BonusItemComponent> _bonusItems = [];
  final List<SwordSlashComponent> _slashPool = [];
  final List<DamageNumber> _damageNumberPool = [];
  final Random _bonusRandom = Random();

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
      'game/diamond.png',
      'game/poison.png',
    ]);

    // === TOP HUD LAYOUT ===
    // Row 1: Health bar — full width, near top
    const topY = 36.0;
    _healthBar = MonsterHealthBar()..position = Vector2(12, topY);
    add(_healthBar);

    // Row 2: Monster (left) | Rep counter (center) | Pace timer (right)
    const row2Y = topY + MonsterHealthBar.barHeight + 8;

    _monster = MonsterComponent()..position = Vector2(24, row2Y + 22);
    add(_monster);

    _repProgress = RepProgressBar()
      ..position = Vector2(MonsterComponent.layoutWidth + 16, row2Y + 4);
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

    final gemSprite = Sprite(images.fromCache('game/diamond.png'));
    final poisonSprite = Sprite(images.fromCache('game/poison.png'));
    final gemItem = BonusItemComponent(kind: BonusItemKind.gem)
      ..sprite = gemSprite;
    _bonusItems.add(gemItem);
    add(gemItem);

    final poisonItem = BonusItemComponent(kind: BonusItemKind.poison)
      ..sprite = poisonSprite;
    _bonusItems.add(poisonItem);
    add(poisonItem);

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
  void configure({
    required WorkoutType workoutType,
    required int cooldownSeconds,
    required double paceIntervalSeconds,
    required GameLaunchArgs launchArgs,
  }) {
    _workoutType = workoutType;
    _cooldownSeconds = cooldownSeconds.clamp(2, 30).toInt();
    _paceIntervalSeconds = paceIntervalSeconds > 0
        ? paceIntervalSeconds
        : kPaceThresholdSeconds;
    _launchArgs = launchArgs;
    _bonusRoundsEnabled =
        launchArgs.bonusRoundsEnabled && !launchArgs.isMultiplayer;
  }

  void _resetGame() {
    _sessionEnded = false;
    _currentRound = 1;
    _monsterMaxHP = repsRequiredForRound(1);
    _monsterHP = _monsterMaxHP;
    _playerLives = kStartingLives;
    _dragonLifeSteals = 0;
    _monster.setLifeStealScale(1.0);
    _bonusGemsCollected = 0;
    _activeBonusNumber = 0;
    _bonusTimeRemaining = 15;
    _bonusElapsedTotal = 0;
    _bonusTargetMoveTimer = 0;
    _bonusEnding = false;
    _bonusEndDelay = 0;
    _lastBonusSpawnCenter = null;
    _lastBonusBodyCenter = null;
    _lastBonusBodyRadius = 0;
    _deactivateBonusItems();

    _totalReps = 0;
    _livesLost = 0;
    _roundsCompleted = 0;
    _sessionStartTime = DateTime.now();
    _repIntervals.clear();
    _lastRepTime = null;
    _lastRepRound = 0;

    _paceTimeRemaining = _paceIntervalSeconds;
    _paceTimerActive = false;

    // Update all components
    _updateHUD();

    // Start initial cooldown for Round 1
    _enterCooldown();
  }

  void _updateHUD() {
    _healthBar.setHP(_monsterHP, _monsterMaxHP);
    _repProgress.setProgress(
      (_monsterMaxHP - _monsterHP).clamp(0, _monsterMaxHP).toInt(),
      _monsterMaxHP,
    );
    _livesDisplay.setLives(_playerLives);
    _roundBanner.setRound(_currentRound);
    _roundBanner.setWorkoutLabel(_workoutType.displayName.toUpperCase());
    _paceIndicator.configure(maxSeconds: _paceIntervalSeconds);
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

    if (_phase == GamePhase.bonusPlaying) {
      _updateBonusRound(dt);
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
    _bonusItems.clear();
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

  void onBonusPose(BonusPoseSnapshot snapshot) {
    if (_phase != GamePhase.bonusPlaying) return;
    _lastBonusBodyCenter = snapshot.bodyCenter;
    _lastBonusBodyRadius = snapshot.bodyRadius;
    _spawnPendingBonusTargetIfReady();
    _handleBonusCollision(snapshot.handPosition);
  }

  /// Force an immediate defeat (e.g. back button press, app paused).
  void forceDefeat() {
    if (_sessionEnded) return;
    if (_phase == GamePhase.victory || _phase == GamePhase.defeat) return;

    _playerLives = 0;
    _livesDisplay.setLives(0);
    _cooldownOverlay.stopCooldown();
    _deactivateBonusItems();
    _handleDefeat();
  }

  // --- Phase Management ---

  void _enterCooldown() {
    _cooldownTarget = _CooldownTarget.normalRound;
    _phase = GamePhase.cooldown;
    _phaseController.add(_phase);

    _paceTimerActive = false;
    _paceIndicator.setActive(false);

    _cooldownOverlay.startCooldown(_currentRound);
    _playAudioSafe('sfx/win_violin.mp3');
  }

  void _enterBonusCooldown(int bonusNumber) {
    _cooldownTarget = _CooldownTarget.beforeBonus;
    _activeBonusNumber = bonusNumber;
    _phase = GamePhase.bonusCooldown;
    _phaseController.add(_phase);

    _paceTimerActive = false;
    _paceIndicator.setActive(false);
    _cooldownOverlay.startCooldown(
      _currentRound + 1,
      title: 'BONUS $bonusNumber',
      caption: 'You currently have $_bonusGemsCollected gems collected.',
      hideWorkoutImage: true,
      captionAtBottom: true,
    );
    _playAudioSafe('sfx/win_violin.mp3');
  }

  void _enterPostBonusCooldown() {
    _currentRound++;
    _monsterMaxHP = repsRequiredForRound(_currentRound);
    _monsterHP = _monsterMaxHP;
    _monster.nextMonster();
    _cooldownTarget = _CooldownTarget.afterBonus;
    _phase = GamePhase.bonusCooldown;
    _phaseController.add(_phase);

    _paceTimerActive = false;
    _paceIndicator.setActive(false);
    _cooldownOverlay.startCooldown(
      _currentRound,
      caption:
          'Bonus round over, $_bonusGemsCollected seconds deducted on clear time. '
          'Be sure to finish this session, warrior!',
    );
    _playAudioSafe('sfx/win_violin.mp3');
  }

  void _onCooldownComplete() {
    if (_cooldownTarget == _CooldownTarget.beforeBonus) {
      _enterBonusPlaying();
      return;
    }

    _cooldownTarget = _CooldownTarget.normalRound;
    // Cooldown done — enter playing phase
    _updateHUD();

    _phase = GamePhase.playing;
    _phaseController.add(_phase);

    // Pace timer starts immediately after cooldown.
    _paceTimeRemaining = _paceIntervalSeconds;
    _paceTimerActive = true;
    _paceIndicator.setActive(true);
  }

  void _enterBonusPlaying() {
    _cooldownTarget = _CooldownTarget.normalRound;
    _phase = GamePhase.bonusPlaying;
    _phaseController.add(_phase);

    _bonusTimeRemaining = 15;
    _bonusTargetMoveTimer = 0;
    _bonusEnding = false;
    _bonusEndDelay = 0;
    _lastBonusSpawnCenter = null;
    _lastBonusBodyCenter = null;
    _lastBonusBodyRadius = 0;
    _paceTimerActive = false;
    _paceIndicator.configure(maxSeconds: 15);
    _paceIndicator.setRemaining(_bonusTimeRemaining);
    _paceIndicator.setActive(true);
    _repProgress.setCustomText('$_bonusGemsCollected GEMS');
    _roundBanner.setCustomRoundLabel('BONUS $_activeBonusNumber');
    _roundBanner.setWorkoutLabel(_workoutType.displayName.toUpperCase());
    _spawnAllBonusItems();
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
    _paceTimeRemaining = _paceIntervalSeconds;
    _paceIndicator.setRemaining(_paceTimeRemaining);

    // Update visuals
    _healthBar.setHP(_monsterHP, _monsterMaxHP);
    _repProgress.setProgress(_monsterMaxHP - _monsterHP, _monsterMaxHP);

    // Monster hit flash
    _monster.flashHit();

    // Spawn slash + damage number
    _spawnHitEffects();

    // Audio
    _playAudioSafe(_monsterHP <= 0 ? 'sfx/damage.mp3' : 'sfx/slash.mp3');

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
          _monster.visualWidth / 2 -
          SwordSlashComponent.slashWidth / 2,
      _monster.position.y +
          _monster.visualHeight / 2 -
          SwordSlashComponent.slashHeight / 2,
    );

    final damageNumber = _damageNumberPool.firstWhere(
      (effect) => !effect.isEffectActive,
      orElse: () => _damageNumberPool.first,
    );
    damageNumber.activateAt(
      _monster.position.x + _monster.visualWidth / 2,
      _monster.position.y + 10,
    );
  }

  void _handlePaceFailure() {
    _playerLives--;
    _livesLost++;

    _livesDisplay.setLives(_playerLives);
    _damageFlash.trigger();
    _playAudioSafe('sfx/thud.mp3');

    if (_playerLives > 0) {
      _monsterHP++;
      _dragonLifeSteals++;
      _monster.setLifeStealScale(
        1.0 + (_dragonLifeSteals * kDragonLifeStealScaleBonus),
      );
    }

    // Reset pace timer after failure
    _paceTimeRemaining = _paceIntervalSeconds;
    _paceIndicator.setRemaining(_paceTimeRemaining);
    _healthBar.setHP(_monsterHP, _monsterMaxHP);
    _repProgress.setProgress(
      (_monsterMaxHP - _monsterHP).clamp(0, _monsterMaxHP).toInt(),
      _monsterMaxHP,
    );

    if (_playerLives <= 0) {
      _handleDefeat();
    }
  }

  void _handleRoundWon() {
    _roundsCompleted++;
    _paceTimerActive = false;
    _paceIndicator.setActive(false);

    // Freeze pace timer display at the full workout-specific interval.
    _paceTimeRemaining = _paceIntervalSeconds;
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
    } else if (_shouldStartBonusAfterRound(_currentRound)) {
      _enterBonusCooldown(_currentRound == 4 ? 1 : 2);
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
    _deactivateBonusItems();

    final endTime = DateTime.now();
    final startTime = _sessionStartTime ?? endTime;
    final rawDurationSeconds =
        endTime.difference(startTime).inMilliseconds / 1000.0;
    final durationSeconds = max(
      0.0,
      rawDurationSeconds -
          _bonusElapsedTotal -
          (won ? _bonusGemsCollected.toDouble() : 0.0),
    );

    double bestInterval = 0.0;
    double avgInterval = 0.0;

    if (_repIntervals.isNotEmpty) {
      bestInterval = _repIntervals.reduce(min);
      avgInterval =
          _repIntervals.reduce((a, b) => a + b) / _repIntervals.length;
    }

    final session = GameSession(
      workoutType: _workoutType,
      won: won,
      totalReps: _totalReps,
      totalRepsRequired: kTotalSessionReps,
      totalTimeSeconds: durationSeconds,
      roundsCompleted: _roundsCompleted,
      bestRepIntervalSeconds: bestInterval,
      avgRepIntervalSeconds: avgInterval,
      livesLost: _livesLost,
      completedAt: endTime,
      launchArgs: _launchArgs,
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

  bool _shouldStartBonusAfterRound(int round) {
    return _bonusRoundsEnabled && (round == 4 || round == 8);
  }

  void _updateBonusRound(double dt) {
    if (_bonusEnding) {
      _bonusEndDelay -= dt;
      if (_bonusEndDelay <= 0) {
        _finishBonusRound();
      }
      return;
    }

    final consumed = min(dt, _bonusTimeRemaining);
    _bonusTimeRemaining = max(0.0, _bonusTimeRemaining - dt);
    _bonusElapsedTotal += consumed;
    _paceIndicator.setRemaining(_bonusTimeRemaining);
    _bonusTargetMoveTimer += dt;

    if (_bonusTargetMoveTimer >= 2) {
      _spawnNextBonusTarget(awayFrom: _activeBonusItem()?.centerOffset);
    }

    if (_bonusTimeRemaining <= 0) {
      _startBonusEndDelay();
    }
  }

  void _handleBonusCollision(Offset handPosition) {
    if (_bonusEnding) return;

    final touchedItem = _closestCollidingItem(handPosition);
    if (touchedItem == null) return;

    if (touchedItem.kind == BonusItemKind.poison) {
      _spawnBonusFeedback(touchedItem.centerOffset, '!');
      _playAudioSafe('sfx/poison.mp3');
      _startBonusEndDelay();
      return;
    }

    _bonusGemsCollected++;
    _repProgress.setCustomText('$_bonusGemsCollected GEMS');
    _spawnBonusFeedback(touchedItem.centerOffset, '+1');
    _playAudioSafe('sfx/ping.mp3');
    _spawnNextBonusTarget(awayFrom: handPosition);
  }

  BonusItemComponent? _closestCollidingItem(Offset handPosition) {
    const touchRadius = 56.0;
    BonusItemComponent? closest;
    double closestDistance = double.infinity;

    for (final item in _bonusItems) {
      if (!item.isActive) continue;
      final distance = (item.centerOffset - handPosition).distance;
      if (distance <= touchRadius + item.size.x * 0.36 &&
          distance < closestDistance) {
        closest = item;
        closestDistance = distance;
      }
    }

    return closest;
  }

  void _finishBonusRound() {
    if (_phase != GamePhase.bonusPlaying) return;
    _deactivateBonusItems();
    _bonusEnding = false;
    _bonusEndDelay = 0;
    _paceIndicator.setActive(false);
    _enterPostBonusCooldown();
  }

  void _spawnAllBonusItems() {
    _deactivateBonusItems();
    _spawnPendingBonusTargetIfReady();
  }

  void _spawnNextBonusTarget({Offset? awayFrom}) {
    _deactivateBonusItems();
    _bonusTargetMoveTimer = 0;
    final kind = _bonusRandom.nextDouble() < 0.7
        ? BonusItemKind.gem
        : BonusItemKind.poison;
    final item = _bonusItemOfKind(kind);
    if (item == null) return;

    item.activateAt(_calculatedBonusPosition(item, awayFrom: awayFrom));
    _lastBonusSpawnCenter = item.centerOffset;
  }

  void _spawnPendingBonusTargetIfReady() {
    if (_bonusEnding || _activeBonusItem() != null) return;
    if (_lastBonusBodyCenter == null) return;
    _spawnNextBonusTarget();
  }

  BonusItemComponent? _activeBonusItem() {
    for (final item in _bonusItems) {
      if (item.isActive) return item;
    }
    return null;
  }

  void _startBonusEndDelay() {
    if (_bonusEnding) return;
    _deactivateBonusItems();
    _bonusTimeRemaining = 0;
    _paceIndicator.setRemaining(0);
    _bonusEnding = true;
    _bonusEndDelay = 2;
  }

  BonusItemComponent? _bonusItemOfKind(BonusItemKind kind) {
    for (final item in _bonusItems) {
      if (item.kind == kind) return item;
    }
    return null;
  }

  Vector2 _calculatedBonusPosition(
    BonusItemComponent item, {
    Offset? awayFrom,
  }) {
    final bounds = _bonusSpawnBounds();
    final itemSize = BonusItemComponent.itemSize;
    final previousCenter = awayFrom ?? _lastBonusSpawnCenter;
    final bodyCenter = _lastBonusBodyCenter;
    final safeBodyDistance = _lastBonusBodyRadius + itemSize * 1.35;
    final candidates = _bonusPlacementCandidates(bounds, itemSize);

    Offset? best;
    var bestScore = -double.infinity;
    for (final candidate in candidates) {
      if (bodyCenter != null &&
          (bodyCenter - candidate).distance < safeBodyDistance) {
        continue;
      }

      final score = _scoreBonusCandidate(
        candidate: candidate,
        previousCenter: previousCenter,
        bodyCenter: bodyCenter,
      );
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    best ??= candidates.reduce((a, b) {
      final aScore = _scoreBonusCandidate(
        candidate: a,
        previousCenter: previousCenter,
        bodyCenter: bodyCenter,
      );
      final bScore = _scoreBonusCandidate(
        candidate: b,
        previousCenter: previousCenter,
        bodyCenter: bodyCenter,
      );
      return bScore > aScore ? b : a;
    });

    return Vector2(best.dx - itemSize / 2, best.dy - itemSize / 2);
  }

  List<Offset> _bonusPlacementCandidates(Rect bounds, double itemSize) {
    const fractions = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
    final candidates = <Offset>[];
    for (final xFraction in fractions) {
      for (final yFraction in fractions) {
        candidates.add(
          Offset(
            bounds.left + itemSize / 2 + (bounds.width - itemSize) * xFraction,
            bounds.top + itemSize / 2 + (bounds.height - itemSize) * yFraction,
          ),
        );
      }
    }
    return candidates;
  }

  double _scoreBonusCandidate({
    required Offset candidate,
    required Offset? previousCenter,
    required Offset? bodyCenter,
  }) {
    final previousDistance = previousCenter == null
        ? 0.0
        : (candidate - previousCenter).distance;
    final bodyDistance = bodyCenter == null
        ? 0.0
        : (candidate - bodyCenter).distance;
    final oppositeScore = previousCenter == null || bodyCenter == null
        ? 0.0
        : _oppositeSideScore(candidate, previousCenter, bodyCenter);
    return previousDistance * 1000 + oppositeScore * 500 + bodyDistance;
  }

  double _oppositeSideScore(
    Offset candidate,
    Offset previousCenter,
    Offset bodyCenter,
  ) {
    final previousVector = previousCenter - bodyCenter;
    final candidateVector = candidate - bodyCenter;
    final denominator = previousVector.distance * candidateVector.distance;
    if (denominator <= 1) return 0;
    final dot =
        previousVector.dx * candidateVector.dx +
        previousVector.dy * candidateVector.dy;
    return (-dot / denominator).clamp(-1.0, 1.0);
  }

  Rect _bonusSpawnBounds() {
    return Rect.fromLTRB(24, 132, size.x - 24, max(132.0, size.y - 178));
  }

  void _deactivateBonusItems() {
    for (final item in _bonusItems) {
      item.deactivate();
    }
  }

  void _spawnBonusFeedback(Offset position, String text) {
    final damageNumber = _damageNumberPool.firstWhere(
      (effect) => !effect.isEffectActive,
      orElse: () => _damageNumberPool.first,
    );
    damageNumber.activateAt(position.dx, position.dy, text: text);
  }
}
