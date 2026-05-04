import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'p2_session_cache.dart';

/// Thrown when Player 2 verification fails for any reason. The [message] is
/// safe to surface directly in the UI.
class P2VerificationException implements Exception {
  final String message;
  const P2VerificationException(this.message);
  @override
  String toString() => 'P2VerificationException: $message';
}

/// Verifies a second player's email via Supabase's existing email-OTP flow,
/// while preserving Player 1's signed-in session.
///
/// Flow:
///   1. [sendOtp] — stash P1's refresh token, then `signInWithOtp` with
///      `shouldCreateUser: false` so we only ping registered FitFusion
///      accounts. The OTP itself goes to P2's inbox.
///   2. [verifyOtp] — call `verifyOTP`. Supabase swaps the active session to
///      P2 momentarily; we immediately call `setSession(P1RefreshToken)` to
///      restore P1. The verified P2 (id + email) is recorded in
///      [P2SessionCache] for in-process recycling.
class P2VerificationService {
  P2VerificationService._();

  static final _client = Supabase.instance.client;

  /// Sends a 6-digit OTP to [rawEmail]. Throws [P2VerificationException] on
  /// any failure (no account, can't send, same as P1, etc).
  static Future<void> sendOtp(String rawEmail) async {
    final email = rawEmail.trim();
    if (email.isEmpty || !email.contains('@')) {
      throw const P2VerificationException(
        'Please enter a valid email address.',
      );
    }

    final p1 = _client.auth.currentUser;
    final p1Session = _client.auth.currentSession;
    if (p1 == null || p1Session == null) {
      throw const P2VerificationException(
        'You must be signed in to start a multiplayer session.',
      );
    }

    if (p1.email != null &&
        p1.email!.toLowerCase() == email.toLowerCase()) {
      throw const P2VerificationException(
        "You can't be your own Player 2.",
      );
    }

    // Stash P1's refresh token now — we need it to restore the session
    // after verifyOTP() swaps Supabase's active user to P2.
    P2SessionCache.instance.stashPendingP1RefreshToken(
      p1Session.refreshToken ?? '',
    );

    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    } on AuthException catch (e) {
      P2SessionCache.instance.consumePendingP1RefreshToken();
      // Generic message per spec — covers "user not found", "signups disabled",
      // rate limits, etc, without leaking which one happened.
      assert(() {
        debugPrint('[P2VerificationService] sendOtp AuthException: ${e.message}');
        return true;
      }());
      throw const P2VerificationException(
        "Couldn't send a code to that email. Make sure Player 2 has a FitFusion account.",
      );
    } catch (e) {
      P2SessionCache.instance.consumePendingP1RefreshToken();
      assert(() {
        debugPrint('[P2VerificationService] sendOtp error: $e');
        return true;
      }());
      throw const P2VerificationException(
        "Couldn't send a code to that email. Please try again.",
      );
    }
  }

  /// Verifies [code] for [rawEmail]. On success, records P2 in the cache
  /// and returns the P2 user id. P1's session is restored before this
  /// future completes — even on failure.
  static Future<String> verifyOtp({
    required String rawEmail,
    required String code,
  }) async {
    final email = rawEmail.trim();
    final pendingP1Refresh =
        P2SessionCache.instance.peekPendingP1RefreshToken();

    if (pendingP1Refresh == null || pendingP1Refresh.isEmpty) {
      throw const P2VerificationException(
        'Verification session expired. Please request a new code.',
      );
    }

    String? p2UserId;
    String? p2RefreshToken;
    Object? caught;

    try {
      // Email OTP type covers signInWithOtp(email:) flows.
      final response = await _client.auth.verifyOTP(
        email: email,
        token: code.trim(),
        type: OtpType.email,
      );
      p2UserId = response.user?.id ?? _client.auth.currentUser?.id;
      // Snapshot P2's refresh token BEFORE we swap the global session back
      // to P1. The token outlives the swap (Supabase only invalidates it on
      // first reuse) and lets the SessionService spin up a transient
      // P2-authenticated client at end-of-session to insert P2's row
      // without tripping `sessions_insert_own` RLS. Captured even on the
      // off-chance the response itself omits it (fall back to the live
      // currentSession which `verifyOTP` has already swapped to P2).
      p2RefreshToken =
          response.session?.refreshToken ??
          _client.auth.currentSession?.refreshToken;
      if (p2UserId == null) {
        throw const P2VerificationException(
          'Verification did not return a user. Please try again.',
        );
      }
    } on AuthException catch (e) {
      caught = P2VerificationException(_friendlyOtpError(e.message));
    } catch (e) {
      caught = const P2VerificationException(
        'Verification failed. Please try again.',
      );
    }

    // ALWAYS restore P1's session, whether verifyOTP succeeded or not.
    try {
      await _client.auth.setSession(pendingP1Refresh);
    } catch (e) {
      assert(() {
        debugPrint('[P2VerificationService] setSession (restore P1) failed: $e');
        return true;
      }());
      // If restoring P1 fails the user is effectively signed out. The
      // app-level auth listener will then bounce them to /auth.
      P2SessionCache.instance.consumePendingP1RefreshToken();
      throw const P2VerificationException(
        'Could not restore your session. Please sign in again.',
      );
    } finally {
      P2SessionCache.instance.consumePendingP1RefreshToken();
    }

    if (caught != null) {
      throw caught;
    }

    P2SessionCache.instance.recordVerified(
      email: email,
      userId: p2UserId!,
      refreshToken: p2RefreshToken,
    );
    return p2UserId;
  }

  /// Resends the OTP. Mirrors [sendOtp] (same Supabase call) so behaviour
  /// stays consistent — but doesn't re-stash the refresh token if one is
  /// already pending.
  static Future<void> resendOtp(String rawEmail) async {
    if (P2SessionCache.instance.peekPendingP1RefreshToken() == null) {
      // No pending verification — go through the full sendOtp path.
      await sendOtp(rawEmail);
      return;
    }
    final email = rawEmail.trim();
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    } on AuthException catch (e) {
      assert(() {
        debugPrint('[P2VerificationService] resendOtp AuthException: ${e.message}');
        return true;
      }());
      throw const P2VerificationException(
        "Couldn't resend the code. Please try again in a moment.",
      );
    } catch (_) {
      throw const P2VerificationException(
        "Couldn't resend the code. Please try again in a moment.",
      );
    }
  }

  static String _friendlyOtpError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('expired')) return 'That code has expired. Send a new one.';
    if (lower.contains('invalid')) return 'That code is incorrect.';
    return 'Verification failed. Please try again.';
  }
}
