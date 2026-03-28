/// The three selectable workout types.
/// These map directly to the three exercise state machines in RepDetector
/// and to the workout_type column in the Supabase sessions table.
enum WorkoutType {
  squats,
  jumpingJacks,
  obliqueCrunches,
}

/// The phases of a game session.
/// FitFusionGame transitions between these during a session.
/// Flow: cooldown → playing → cooldown → ... → victory | defeat
enum GamePhase {
  /// Between rounds. Rep detection and pace timer are paused.
  /// Countdown is running. Next round begins after kCooldownSeconds.
  /// Also the initial phase — Round 1 starts with a cooldown.
  cooldown,

  /// Active round. Pace timer is running. Reps deal damage.
  /// Pace failures cost lives.
  playing,

  /// Terminal state: all 10 rounds completed with at least 1 life remaining.
  victory,

  /// Terminal state: all 3 lives lost at any point during the session.
  defeat,
}

/// Event types emitted by PaceMonitor.
enum PaceEventType {
  /// A rep was detected within the pace threshold window. Timer was reset.
  repOnTime,

  /// No rep was detected within kPaceThresholdSeconds. Player loses a life.
  paceFailed,
}

/// The three leaderboard metrics tracked per workout type.
/// Matches the CHECK constraint on leaderboard_entries.metric in DATABASE.md.
enum LeaderboardMetric {
  /// Fastest time to complete a full 10-round winning session (seconds).
  /// Only from won sessions.
  clearTime,

  /// Fastest single rep interval recorded across all sessions (seconds).
  bestRepInterval,

  /// Lowest average rep interval in a single session (seconds).
  /// Only from sessions with at least 2 reps.
  avgRepInterval,
}

/// IDs for all 11 achievements — ordered by index in the README table.
/// Local persistence uses SharedPreferences until Supabase integration.
enum AchievementId {
  firstBlood,           // #1  — Complete your first session
  ironWill,             // #2  — Complete 30 total sessions
  bloodPumper,          // #3  — Reach 300 lifetime reps
  survivor,             // #4  — Complete 100 total rounds
  halfwayHero,          // #5  — Reach 5 rounds in a single session
  monsterHunter,        // #6  — Win a full 10-round session
  tripleCrown,          // #7  — Win at least one session in all 3 workout types
  speedDemon,           // #8  — Best rep interval under 1.8 seconds
  blindingSteel,        // #9  — Win with avg rep interval under 2.3 sec
  untouchable,          // #10 — Win with 0 lives lost
  lastStand,            // #11 — Win with exactly 2 lives lost
}
