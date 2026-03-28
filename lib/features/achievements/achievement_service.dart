import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/extensions.dart';
import '../game/game_session.dart';

/// Local achievement persistence and evaluation service.
/// Uses SharedPreferences as temporary storage until Supabase integration.
/// Tracks lifetime stats and determines which achievements are newly unlocked
/// after each game session.
class AchievementService {
  late SharedPreferences _prefs;
  final Set<String> _unlocked = {};

  // --- SharedPreferences Keys ---
  static const String _kUnlocked = 'ff_unlocked_achievements';
  static const String _kLifetimeSessions = 'ff_lifetime_sessions';
  static const String _kLifetimeReps = 'ff_lifetime_reps';
  static const String _kLifetimeRounds = 'ff_lifetime_rounds';
  static const String _kVictoriesSquats = 'ff_victories_squats';
  static const String _kVictoriesJacks = 'ff_victories_jumping_jacks';
  static const String _kVictoriesCrunches = 'ff_victories_side_crunches';
  static const String _kPbTimeSquats = 'ff_pb_time_squats';
  static const String _kPbTimeJacks = 'ff_pb_time_jumping_jacks';
  static const String _kPbTimeCrunches = 'ff_pb_time_side_crunches';
  static const String _kPbIntervalSquats = 'ff_pb_interval_squats';
  static const String _kPbIntervalJacks = 'ff_pb_interval_jumping_jacks';
  static const String _kPbIntervalCrunches = 'ff_pb_interval_side_crunches';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _unlocked.addAll(_prefs.getStringList(_kUnlocked) ?? []);
    debugPrint('[AchievementService] Loaded ${_unlocked.length} unlocked achievements');
  }

  bool isUnlocked(AchievementId id) => _unlocked.contains(id.dbKey);

  Set<AchievementId> get unlockedAchievements {
    final result = <AchievementId>{};
    for (final id in AchievementId.values) {
      if (_unlocked.contains(id.dbKey)) {
        result.add(id);
      }
    }
    return result;
  }

  /// Evaluates all 11 achievements against the completed session.
  /// Updates lifetime stats FIRST, then checks conditions.
  /// Returns the list of NEWLY unlocked achievements (empty if none).
  Future<List<AchievementId>> evaluateSession(GameSession session) async {
    // --- Update lifetime stats ---
    final lifetimeSessions = (_prefs.getInt(_kLifetimeSessions) ?? 0) + 1;
    final lifetimeReps = (_prefs.getInt(_kLifetimeReps) ?? 0) + session.totalReps;
    final lifetimeRounds = (_prefs.getInt(_kLifetimeRounds) ?? 0) + session.roundsCompleted;

    await _prefs.setInt(_kLifetimeSessions, lifetimeSessions);
    await _prefs.setInt(_kLifetimeReps, lifetimeReps);
    await _prefs.setInt(_kLifetimeRounds, lifetimeRounds);

    // Update per-workout victories
    if (session.won) {
      final victoryKey = _victoryKeyForWorkout(session.workoutType);
      final victories = (_prefs.getInt(victoryKey) ?? 0) + 1;
      await _prefs.setInt(victoryKey, victories);
    }

    // --- Personal Best tracking ---
    // PB clear time — only for winning sessions
    final pbTimeKey = _pbTimeKeyForWorkout(session.workoutType);
    final previousPbTime = _prefs.getDouble(pbTimeKey) ?? 0.0;
    if (session.won) {
      if (previousPbTime <= 0.0) {
        // First win — initialize PB clear time
        await _prefs.setDouble(pbTimeKey, session.totalTimeSeconds);
      } else if (session.totalTimeSeconds < previousPbTime) {
        await _prefs.setDouble(pbTimeKey, session.totalTimeSeconds);
      }
    }

    // PB rep interval — any session with valid intervals
    final pbIntervalKey = _pbIntervalKeyForWorkout(session.workoutType);
    final previousPbInterval = _prefs.getDouble(pbIntervalKey) ?? 0.0;
    if (session.bestRepIntervalSeconds > 0) {
      if (previousPbInterval <= 0.0) {
        // First recorded interval — initialize PB rep interval
        await _prefs.setDouble(pbIntervalKey, session.bestRepIntervalSeconds);
      } else if (session.bestRepIntervalSeconds < previousPbInterval) {
        await _prefs.setDouble(pbIntervalKey, session.bestRepIntervalSeconds);
      }
    }

    // --- Evaluate each achievement ---
    final newlyUnlocked = <AchievementId>[];

    // Collect per-workout victories for Triple Crown check
    final squatVictories = _prefs.getInt(_kVictoriesSquats) ?? 0;
    final jacksVictories = _prefs.getInt(_kVictoriesJacks) ?? 0;
    final crunchVictories = _prefs.getInt(_kVictoriesCrunches) ?? 0;

    for (final id in AchievementId.values) {
      if (_unlocked.contains(id.dbKey)) continue; // already unlocked

      final unlocked = _checkAchievement(
        id: id,
        session: session,
        lifetimeSessions: lifetimeSessions,
        lifetimeReps: lifetimeReps,
        lifetimeRounds: lifetimeRounds,
        squatVictories: squatVictories,
        jacksVictories: jacksVictories,
        crunchVictories: crunchVictories,
      );

      if (unlocked) {
        newlyUnlocked.add(id);
        _unlocked.add(id.dbKey);
      }
    }

    // Persist updated unlocked set
    if (newlyUnlocked.isNotEmpty) {
      await _prefs.setStringList(_kUnlocked, _unlocked.toList());
      for (final id in newlyUnlocked) {
        debugPrint('[AchievementService] UNLOCKED: ${id.displayName}');
      }
    }

    return newlyUnlocked;
  }

  bool _checkAchievement({
    required AchievementId id,
    required GameSession session,
    required int lifetimeSessions,
    required int lifetimeReps,
    required int lifetimeRounds,
    required int squatVictories,
    required int jacksVictories,
    required int crunchVictories,
  }) {
    switch (id) {
      case AchievementId.firstBlood:
        // #1 — Complete your first session (win or lose)
        return lifetimeSessions >= 1;

      case AchievementId.ironWill:
        // #2 — Complete 30 total sessions
        return lifetimeSessions >= kIronWillSessions;

      case AchievementId.bloodPumper:
        // #3 — Reach 300 lifetime reps
        return lifetimeReps >= kBloodPumperReps;

      case AchievementId.survivor:
        // #4 — Complete 100 total rounds
        return lifetimeRounds >= kSurvivorRounds;

      case AchievementId.halfwayHero:
        // #5 — Reach 5 rounds in a single session
        return session.roundsCompleted >= 5;

      case AchievementId.monsterHunter:
        // #6 — Win a full 10-round session
        return session.won;

      case AchievementId.tripleCrown:
        // #7 — Win at least one session in all 3 workout types
        return squatVictories >= 1 &&
               jacksVictories >= 1 &&
               crunchVictories >= 1;

      case AchievementId.speedDemon:
        // #8 — Best rep interval under 1.8 seconds
        return session.bestRepIntervalSeconds > 0 &&
               session.bestRepIntervalSeconds < kSpeedDemonThreshold;

      case AchievementId.blindingSteel:
        // #9 — Win with average rep interval under 2.3 sec
        return session.won &&
               session.avgRepIntervalSeconds > 0 &&
               session.avgRepIntervalSeconds < kBlindingSteelThreshold;

      case AchievementId.untouchable:
        // #10 — Win with 0 lives lost
        return session.won && session.livesLost == 0;

      case AchievementId.lastStand:
        // #11 — Win with exactly 2 lives lost
        return session.won && session.livesLost == 2;
    }
  }

  // --- Key helpers ---

  String _victoryKeyForWorkout(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:         return _kVictoriesSquats;
      case WorkoutType.jumpingJacks:   return _kVictoriesJacks;
      case WorkoutType.obliqueCrunches: return _kVictoriesCrunches;
    }
  }

  String _pbTimeKeyForWorkout(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:         return _kPbTimeSquats;
      case WorkoutType.jumpingJacks:   return _kPbTimeJacks;
      case WorkoutType.obliqueCrunches: return _kPbTimeCrunches;
    }
  }

  String _pbIntervalKeyForWorkout(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:         return _kPbIntervalSquats;
      case WorkoutType.jumpingJacks:   return _kPbIntervalJacks;
      case WorkoutType.obliqueCrunches: return _kPbIntervalCrunches;
    }
  }
}
