import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/extensions.dart';
import '../features/game/game_session.dart';
import '../features/multiplayer/p2_session_cache.dart';

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

  /// Persists the partner row for a multiplayer session under Player 2's
  /// own auth identity.
  ///
  /// The `sessions_insert_own` RLS policy enforces `auth.uid() = user_id`,
  /// so the primary client (signed in as P1) cannot write a row whose
  /// `user_id` is P2. Without adding columns or relaxing RLS, we satisfy
  /// the policy by spinning up a **transient, in-process** SupabaseClient
  /// authenticated as P2 using the refresh token captured during OTP
  /// verification (see [P2VerificationService.verifyOtp]). The transient
  /// client never touches global state — P1's primary client and its
  /// realtime subscriptions are completely untouched.
  ///
  /// Returns `true` if P2's row landed; `false` (silent) on any failure
  /// path (no cached token, refresh expired, network error, RLS reject).
  /// Failures here must not block P1's own save flow.
  static Future<bool> trySaveMultiplayerPlayer2Session(
    GameSession session,
  ) async {
    if (!session.launchArgs.isMultiplayer) return false;

    final player2UserId = session.launchArgs.player2UserId;
    if (player2UserId == null || player2UserId.isEmpty) return false;

    final p2RefreshToken = P2SessionCache.instance.p2RefreshToken;
    if (p2RefreshToken == null || p2RefreshToken.isEmpty) {
      assert(() {
        debugPrint(
          '[SessionService] Multiplayer partner save skipped: no cached '
          'P2 refresh token. Was P2 verified via OTP this app session?',
        );
        return true;
      }());
      return false;
    }

    final payload = _buildSessionPayload(
      session: session,
      userId: player2UserId,
    );

    SupabaseClient? p2Client;
    try {
      // Stand-alone client — its own GoTrue + PostgREST instances. No
      // realtime subscriptions, no shared state with `Supabase.instance`.
      p2Client = SupabaseClient(kSupabaseUrl, kSupabaseAnonKey);

      // Exchange the cached refresh token for a fresh access token. After
      // this, the client's PostgREST calls will carry P2's JWT, so
      // `auth.uid()` inside RLS will resolve to `player2UserId` and the
      // `sessions_insert_own` WITH CHECK (auth.uid() = user_id) clause
      // is satisfied naturally.
      await p2Client.auth.setSession(p2RefreshToken);

      // Sanity check: caller is genuinely the expected P2.
      final actualP2 = p2Client.auth.currentUser?.id;
      if (actualP2 != player2UserId) {
        assert(() {
          debugPrint(
            '[SessionService] Refused P2 save: cached refresh token '
            'resolved to $actualP2, expected $player2UserId',
          );
          return true;
        }());
        return false;
      }

      await p2Client.from('sessions').insert(payload);

      // Supabase rotates refresh tokens on every use by default; capture
      // the rotated one back into the cache so a subsequent multiplayer
      // match in the same app session can still authenticate as P2.
      final rotated = p2Client.auth.currentSession?.refreshToken;
      P2SessionCache.instance.updateP2RefreshToken(rotated);

      return true;
    } on PostgrestException catch (e) {
      assert(() {
        debugPrint(
          '[SessionService] Multiplayer partner save skipped: ${e.message}',
        );
        return true;
      }());
      return false;
    } on AuthException catch (e) {
      // Refresh token expired/invalid — drop it so we don't keep retrying
      // with a known-bad token. Player will need to re-verify P2 next match.
      P2SessionCache.instance.clearP2RefreshToken();
      assert(() {
        debugPrint(
          '[SessionService] Multiplayer partner save skipped (auth): '
          '${e.message}',
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
    } finally {
      // Tear down the transient client so its background timers (token
      // refresh) don't outlive this call.
      try {
        await p2Client?.dispose();
      } catch (_) {}
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
