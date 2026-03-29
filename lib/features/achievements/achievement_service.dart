import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/extensions.dart';
import '../game/game_session.dart';

/// Supabase-backed achievement persistence and evaluation service.
/// On init, loads the current user's unlocked achievements from user_achievements.
/// On evaluateSession, reads freshly-updated user_stats from Supabase (written
/// by the DB trigger after session insert), evaluates all 11 achievements,
/// and writes any newly unlocked ones back to user_achievements.
class AchievementService {
  static final _client = Supabase.instance.client;

  final Set<String> _unlocked = {};

  Future<void> init() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('user_achievements')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return;

      for (final id in AchievementId.values) {
        if (row[id.dbKey] == true) {
          _unlocked.add(id.dbKey);
        }
      }
      assert(() {
        debugPrint('[AchievementService] Loaded ${_unlocked.length} unlocked achievements');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('[AchievementService] init error: $e');
        return true;
      }());
    }
  }

  bool isUnlocked(AchievementId id) => _unlocked.contains(id.dbKey);

  Set<AchievementId> get unlockedAchievements {
    final result = <AchievementId>{};
    for (final id in AchievementId.values) {
      if (_unlocked.contains(id.dbKey)) result.add(id);
    }
    return result;
  }

  /// Evaluates all 11 achievements after a session has been saved.
  /// Reads user_stats from Supabase (already updated by DB trigger).
  /// Writes newly unlocked achievements to user_achievements.
  /// Returns the list of NEWLY unlocked achievements (empty if none).
  Future<List<AchievementId>> evaluateSession(GameSession session) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    // --- Fetch updated stats from DB (trigger has already run) ---
    Map<String, dynamic>? stats;
    try {
      stats = await _client
          .from('user_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (e) {
      assert(() {
        debugPrint('[AchievementService] Failed to fetch user_stats: $e');
        return true;
      }());
      return [];
    }

    if (stats == null) return [];

    final lifetimeSessions = (stats['total_sessions'] as int?) ?? 0;
    final lifetimeReps     = (stats['total_reps'] as int?) ?? 0;
    final lifetimeRounds   = (stats['total_rounds'] as int?) ?? 0;
    final squatVictories   = (stats['squats_victories'] as int?) ?? 0;
    final jacksVictories   = (stats['jacks_victories'] as int?) ?? 0;
    final crunchVictories  = (stats['crunches_victories'] as int?) ?? 0;

    // --- Evaluate each achievement ---
    final newlyUnlocked = <AchievementId>[];

    for (final id in AchievementId.values) {
      if (_unlocked.contains(id.dbKey)) continue;

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

    // --- Persist newly unlocked to Supabase ---
    if (newlyUnlocked.isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      final updates = <String, dynamic>{};
      for (final id in newlyUnlocked) {
        updates[id.dbKey] = true;
        updates['${id.dbKey}_unlocked_at'] = now;
        assert(() {
          debugPrint('[AchievementService] UNLOCKED: ${id.displayName}');
          return true;
        }());
      }

      try {
        await _client
            .from('user_achievements')
            .update(updates)
            .eq('user_id', user.id);
      } catch (e) {
        assert(() {
          debugPrint('[AchievementService] Failed to persist achievements: $e');
          return true;
        }());
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
        return lifetimeSessions >= 1;

      case AchievementId.ironWill:
        return lifetimeSessions >= kIronWillSessions;

      case AchievementId.bloodPumper:
        return lifetimeReps >= kBloodPumperReps;

      case AchievementId.survivor:
        return lifetimeRounds >= kSurvivorRounds;

      case AchievementId.halfwayHero:
        return session.roundsCompleted >= 5;

      case AchievementId.monsterHunter:
        return session.won;

      case AchievementId.tripleCrown:
        return squatVictories >= 1 &&
               jacksVictories >= 1 &&
               crunchVictories >= 1;

      case AchievementId.speedDemon:
        return session.bestRepIntervalSeconds > 0 &&
               session.bestRepIntervalSeconds < kSpeedDemonThreshold;

      case AchievementId.blindingSteel:
        return session.won &&
               session.avgRepIntervalSeconds > 0 &&
               session.avgRepIntervalSeconds < kBlindingSteelThreshold;

      case AchievementId.untouchable:
        return session.won && session.livesLost == 0;

      case AchievementId.lastStand:
        return session.won && session.livesLost == 2;
    }
  }
}
