import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/extensions.dart';
import '../features/game/game_session.dart';

/// Handles persisting completed game sessions to Supabase.
/// Inserts a row into the sessions table. Stats and leaderboards
/// are derived from database views (no triggers needed).
class SessionService {
  static final _client = Supabase.instance.client;

  /// Inserts the completed [session] into the sessions table.
  /// Throws a [SessionSaveException] on failure.
  static Future<void> saveSession(GameSession session) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw SessionSaveException('No authenticated user — cannot save session.');
    }

    // On defeat, timing stats are forfeit — save as NULL.
    // Only lifetime-aggregatable fields (reps, rounds, lives_lost) are persisted.
    final isVictory = session.won;

    final payload = {
      'user_id': user.id,
      'workout_type': session.workoutType.dbKey,
      'won': session.won,
      'rounds_completed': session.roundsCompleted,
      'total_reps': session.totalReps,
      'lives_lost': session.livesLost,
      'total_time_seconds': isVictory ? session.totalTimeSeconds : null,
      'best_rep_interval_seconds': isVictory
          ? (session.bestRepIntervalSeconds > 0 ? session.bestRepIntervalSeconds : null)
          : null,
      'avg_rep_interval_seconds': isVictory
          ? (session.avgRepIntervalSeconds > 0 ? session.avgRepIntervalSeconds : null)
          : null,
      'completed_at': session.completedAt.toUtc().toIso8601String(),
    };

    try {
      await _client.from('sessions').insert(payload);
    } on PostgrestException catch (e) {
      throw SessionSaveException('Database error: ${e.message}');
    } catch (e) {
      throw SessionSaveException('Unexpected error: $e');
    }
  }
}

/// Thrown when a session cannot be persisted to Supabase.
class SessionSaveException implements Exception {
  final String message;
  const SessionSaveException(this.message);

  @override
  String toString() => 'SessionSaveException: $message';
}
