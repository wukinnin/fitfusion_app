import 'package:flutter/foundation.dart';
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
      throw SessionSaveException(
        'No authenticated user — cannot save session.',
      );
    }

    final payload = _buildSessionPayload(session: session, userId: user.id);

    try {
      await _client.from('sessions').insert(payload);
    } on PostgrestException catch (e) {
      throw SessionSaveException('Database error: ${e.message}');
    } catch (e) {
      throw SessionSaveException('Unexpected error: $e');
    }
  }

  static Future<bool> trySaveMultiplayerPlayer2Session(
    GameSession session,
  ) async {
    if (!session.launchArgs.isMultiplayer) return false;

    final player2UserId = session.launchArgs.player2UserId;
    if (player2UserId == null || player2UserId.isEmpty) return false;

    final payload = _buildSessionPayload(
      session: session,
      userId: player2UserId,
    );

    try {
      await _client.from('sessions').insert(payload);
      return true;
    } on PostgrestException catch (e) {
      assert(() {
        debugPrint(
          '[SessionService] Multiplayer partner save skipped: ${e.message}',
        );
        return true;
      }());
      return false;
    } catch (e) {
      assert(() {
        debugPrint('[SessionService] Multiplayer partner save skipped: $e');
        return true;
      }());
      return false;
    }
  }

  static Map<String, dynamic> _buildSessionPayload({
    required GameSession session,
    required String userId,
  }) {
    // On defeat, timing stats are forfeit — save as NULL.
    // Only lifetime-aggregatable fields (reps, rounds, lives_lost) are persisted.
    final isVictory = session.won;

    final payload = <String, dynamic>{
      'user_id': userId,
      'workout_type': session.workoutType.dbKey,
      'won': session.won,
      'rounds_completed': session.roundsCompleted,
      'total_reps': session.totalReps,
      'lives_lost': session.livesLost,
      'total_time_seconds': isVictory ? session.totalTimeSeconds : null,
      'best_rep_interval_seconds': isVictory
          ? (session.bestRepIntervalSeconds > 0
                ? session.bestRepIntervalSeconds
                : null)
          : null,
      'avg_rep_interval_seconds': isVictory
          ? (session.avgRepIntervalSeconds > 0
                ? session.avgRepIntervalSeconds
                : null)
          : null,
      'completed_at': session.completedAt.toUtc().toIso8601String(),
    };

    return payload;
  }
}

/// Thrown when a session cannot be persisted to Supabase.
class SessionSaveException implements Exception {
  final String message;
  const SessionSaveException(this.message);

  @override
  String toString() => 'SessionSaveException: $message';
}
