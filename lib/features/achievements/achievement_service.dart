import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/extensions.dart';
import '../game/game_session.dart';

/// Supabase-backed achievement persistence and evaluation service.
///
/// Schema (schema-rev2):
///   achievements        — master table (id, code, title, description)
///   user_achievements   — junction table (user_id, achievement_id, unlocked_at)
///   v_user_lifetime_stats — view aggregating sessions per user
///
/// On init, loads the current user's unlocked achievement codes from the
/// user_achievements junction table joined with achievements.
///
/// On evaluateSession, queries lifetime stats from views + per-workout
/// victories from sessions, evaluates all 11 achievement conditions,
/// and inserts newly unlocked rows into user_achievements.
class AchievementService {
  static final _client = Supabase.instance.client;

  /// Cached map of unlocked achievement codes → unlock timestamps.
  final Map<String, DateTime> _unlocked = {};

  /// Cached mapping of achievement code → achievement id (smallint PK).
  /// Populated on first init so we can insert into user_achievements.
  final Map<String, int> _codeToId = {};

  Future<void> init() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // Load all achievement master rows (only 11 rows, safe to fetch all)
      final allAchievements = await _client
          .from('achievements')
          .select('id, code');
      for (final row in allAchievements) {
        _codeToId[row['code'] as String] = row['id'] as int;
      }

      // Load this user's unlocked achievements via junction table
      final rows = await _client
          .from('user_achievements')
          .select('achievement_id, unlocked_at, achievements(code)')
          .eq('user_id', user.id);

      for (final row in rows) {
        final nested = row['achievements'];
        if (nested is Map && nested['code'] != null) {
          final code = nested['code'] as String;
          final ts = row['unlocked_at'] as String?;
          _unlocked[code] = ts != null ? DateTime.parse(ts) : DateTime.now();
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

  bool isUnlocked(AchievementId id) => _unlocked.containsKey(id.dbKey);

  Set<AchievementId> get unlockedAchievements {
    final result = <AchievementId>{};
    for (final id in AchievementId.values) {
      if (_unlocked.containsKey(id.dbKey)) result.add(id);
    }
    return result;
  }

  /// Returns a map of unlocked AchievementId → unlock DateTime.
  Map<AchievementId, DateTime> get unlockedDates {
    final result = <AchievementId, DateTime>{};
    for (final id in AchievementId.values) {
      final ts = _unlocked[id.dbKey];
      if (ts != null) result[id] = ts;
    }
    return result;
  }

  /// Evaluates all 11 achievements after a session has been saved.
  /// Queries lifetime stats from v_user_lifetime_stats view and
  /// per-workout victories from sessions table.
  /// Inserts newly unlocked rows into user_achievements junction table.
  /// Returns the list of NEWLY unlocked achievements (empty if none).
  Future<List<AchievementId>> evaluateSession(GameSession session) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    // --- Fetch lifetime stats from view ---
    int lifetimeSessions = 0;
    int lifetimeReps = 0;
    int lifetimeRounds = 0;

    try {
      final stats = await _client
          .from('v_user_lifetime_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (stats != null) {
        lifetimeSessions = (stats['total_sessions'] as int?) ?? 0;
        lifetimeReps = (stats['total_reps'] as int?) ?? 0;
        lifetimeRounds = (stats['total_rounds'] as int?) ?? 0;
      }
    } catch (e) {
      assert(() {
        debugPrint('[AchievementService] Failed to fetch lifetime stats: $e');
        return true;
      }());
      return [];
    }

    // --- Fetch per-workout victory counts for Triple Crown ---
    int squatVictories = 0;
    int jacksVictories = 0;
    int crunchVictories = 0;

    try {
      final victories = await _client
          .from('sessions')
          .select('workout_type')
          .eq('user_id', user.id)
          .eq('won', true);

      for (final row in victories) {
        switch (row['workout_type'] as String) {
          case 'squats':
            squatVictories++;
            break;
          case 'jumping_jacks':
            jacksVictories++;
            break;
          case 'side_crunches':
            crunchVictories++;
            break;
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('[AchievementService] Failed to fetch victory counts: $e');
        return true;
      }());
    }

    // --- Evaluate each achievement ---
    final newlyUnlocked = <AchievementId>[];

    for (final id in AchievementId.values) {
      if (_unlocked.containsKey(id.dbKey)) continue;

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
        _unlocked[id.dbKey] = DateTime.now();
      }
    }

    // --- Persist newly unlocked to user_achievements junction table ---
    if (newlyUnlocked.isNotEmpty) {
      final inserts = <Map<String, dynamic>>[];
      for (final id in newlyUnlocked) {
        final achievementId = _codeToId[id.dbKey];
        if (achievementId == null) continue;
        inserts.add({
          'user_id': user.id,
          'achievement_id': achievementId,
        });
        assert(() {
          debugPrint('[AchievementService] UNLOCKED: ${id.displayName}');
          return true;
        }());
      }

      try {
        await _client.from('user_achievements').insert(inserts);
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
        return session.won &&
               session.bestRepIntervalSeconds > 0 &&
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
