import 'enums.dart';

extension WorkoutTypeExtension on WorkoutType {
  /// Human-readable display name for UI labels.
  String get displayName {
    switch (this) {
      case WorkoutType.squats:
        return 'Squats';
      case WorkoutType.jumpingJacks:
        return 'Jumping Jacks';
      case WorkoutType.obliqueCrunches:
        return 'Side Oblique Crunches';
    }
  }

  /// Database-safe key for use as column/table identifiers.
  /// Must match the CHECK constraint in supabase/schema.sql exactly.
  String get dbKey {
    switch (this) {
      case WorkoutType.squats:
        return 'squats';
      case WorkoutType.jumpingJacks:
        return 'jumping_jacks';
      case WorkoutType.obliqueCrunches:
        return 'side_crunches';
    }
  }

  /// Short label for compact UI (e.g., tab headers).
  String get shortName {
    switch (this) {
      case WorkoutType.squats:
        return 'Squats';
      case WorkoutType.jumpingJacks:
        return 'Jacks';
      case WorkoutType.obliqueCrunches:
        return 'Crunches';
    }
  }
}

extension AchievementIdExtension on AchievementId {
  /// 1-based display index matching the README achievements table order.
  int get index {
    switch (this) {
      case AchievementId.firstBlood:           return 1;
      case AchievementId.ironWill:             return 2;
      case AchievementId.bloodPumper:          return 3;
      case AchievementId.survivor:             return 4;
      case AchievementId.halfwayHero:          return 5;
      case AchievementId.monsterHunter:        return 6;
      case AchievementId.tripleCrown:          return 7;
      case AchievementId.speedDemon:           return 8;
      case AchievementId.blindingSteel:        return 9;
      case AchievementId.recordBreaker:        return 10;
      case AchievementId.sharperThanYesterday: return 11;
      case AchievementId.untouchable:          return 12;
      case AchievementId.lastStand:            return 13;
    }
  }

  /// Database column key matching the user_achievements table in DATABASE.md.
  String get dbKey {
    switch (this) {
      case AchievementId.firstBlood:           return 'first_blood';
      case AchievementId.ironWill:             return 'iron_will';
      case AchievementId.bloodPumper:          return 'blood_pumper';
      case AchievementId.survivor:             return 'survivor';
      case AchievementId.halfwayHero:          return 'halfway_hero';
      case AchievementId.monsterHunter:        return 'monster_hunter';
      case AchievementId.tripleCrown:          return 'triple_crown';
      case AchievementId.speedDemon:           return 'speed_demon';
      case AchievementId.blindingSteel:        return 'blinding_steel';
      case AchievementId.recordBreaker:        return 'record_breaker';
      case AchievementId.sharperThanYesterday: return 'sharper_than_yesterday';
      case AchievementId.untouchable:          return 'untouchable';
      case AchievementId.lastStand:            return 'last_stand';
    }
  }

  String get displayName {
    switch (this) {
      case AchievementId.firstBlood:           return 'First Blood';
      case AchievementId.ironWill:             return 'Iron Will';
      case AchievementId.bloodPumper:          return 'Blood Pumper';
      case AchievementId.survivor:             return 'Survivor';
      case AchievementId.halfwayHero:          return 'Halfway Hero';
      case AchievementId.monsterHunter:        return 'Monster Hunter';
      case AchievementId.tripleCrown:          return 'Triple Crown';
      case AchievementId.speedDemon:           return 'Speed Demon';
      case AchievementId.blindingSteel:        return 'Blinding Steel';
      case AchievementId.recordBreaker:        return 'Record Breaker';
      case AchievementId.sharperThanYesterday: return 'Sharper Than Yesterday';
      case AchievementId.untouchable:          return 'Untouchable';
      case AchievementId.lastStand:            return 'Last Stand';
    }
  }

  String get description {
    switch (this) {
      case AchievementId.firstBlood:           return 'Complete your first session (win or lose).';
      case AchievementId.ironWill:             return 'Complete 30 total sessions.';
      case AchievementId.bloodPumper:          return 'Reach 300 lifetime reps.';
      case AchievementId.survivor:             return 'Complete 100 total rounds.';
      case AchievementId.halfwayHero:          return 'Reach 5 rounds in a single session.';
      case AchievementId.monsterHunter:        return 'Win a full 10-round session.';
      case AchievementId.tripleCrown:          return 'Win at least one session in all 3 workout types.';
      case AchievementId.speedDemon:           return 'Achieve a best rep interval under 1.8 seconds.';
      case AchievementId.blindingSteel:        return 'Win with an average rep interval under 2.3 sec.';
      case AchievementId.recordBreaker:        return 'Beat your personal best clear time.';
      case AchievementId.sharperThanYesterday: return 'Beat your personal best rep interval.';
      case AchievementId.untouchable:          return 'Win with 0 lives lost.';
      case AchievementId.lastStand:            return 'Win with exactly 2 lives lost.';
    }
  }
}

extension LeaderboardMetricExtension on LeaderboardMetric {
  /// Database key matching the leaderboard_entries.metric CHECK constraint.
  String get dbKey {
    switch (this) {
      case LeaderboardMetric.clearTime:        return 'clear_time';
      case LeaderboardMetric.bestRepInterval:  return 'best_rep_interval';
      case LeaderboardMetric.avgRepInterval:   return 'avg_rep_interval';
    }
  }

  /// Human-readable label for UI display.
  String get displayName {
    switch (this) {
      case LeaderboardMetric.clearTime:        return 'Clear Time';
      case LeaderboardMetric.bestRepInterval:  return 'Best Rep Interval';
      case LeaderboardMetric.avgRepInterval:   return 'Avg Rep Interval';
    }
  }
}
