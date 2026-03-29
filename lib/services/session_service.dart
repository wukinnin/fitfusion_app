import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/extensions.dart';
import '../features/game/game_session.dart';

/// Handles persisting completed game sessions to Supabase.
/// Inserts a row into the sessions table; the DB trigger
/// update_stats_on_session() then updates user_stats and leaderboards.
class SessionService {
  static final _client = Supabase.instance.client;

  /// Inserts the completed [session] into the sessions table.
  /// Throws a [SessionSaveException] on failure.
  static Future<void> saveSession(GameSession session) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw SessionSaveException('No authenticated user — cannot save session.');
    }

    final payload = {
      'user_id': user.id,
      'workout_type': session.workoutType.dbKey,
      'won': session.won,
      'rounds_completed': session.roundsCompleted,
      'total_reps': session.totalReps,
      'lives_lost': session.livesLost,
      'total_time_seconds': session.totalTimeSeconds,
      'best_rep_interval_seconds':
          session.bestRepIntervalSeconds > 0 ? session.bestRepIntervalSeconds : null,
      'avg_rep_interval_seconds':
          session.avgRepIntervalSeconds > 0 ? session.avgRepIntervalSeconds : null,
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
