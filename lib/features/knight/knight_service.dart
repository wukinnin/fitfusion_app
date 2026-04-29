import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'knight_disposition.dart';

/// Per-user local store + disposition evaluator for the Fitness Knight.
///
/// All state is kept on-device in [SharedPreferences], namespaced by user id,
/// so switching accounts on the same device yields independent Knight states.
class KnightService {
  KnightService._();

  // SharedPreferences key prefix.
  static const _prefix = 'knight';

  // A "qualifying" session must reach at least this many rounds to count
  // toward the Praise disposition. Prevents zero-effort sessions from
  // earning praise.
  static const int kQualifyingRounds = 3;

  // Disposition thresholds (durations measured against `now`).
  // Two-signal ladder: app-open (primary) + session (Praise + fallback).
  static const Duration kPraiseWindow = Duration(hours: 24);
  static const Duration kQuestionedWindow = Duration(hours: 48);
  static const Duration kInactiveThreshold = Duration(days: 7);

  /// Bumps every time something happens that could change a user's
  /// disposition (stamp written, test override toggled, state cleared).
  /// Widgets that render disposition-sensitive UI (e.g. the home-screen
  /// `KnightCard`) listen to this so they re-evaluate immediately without
  /// waiting for a route change or manual rebuild.
  static final ValueNotifier<int> dispositionRevision = ValueNotifier<int>(0);

  static void _bump() {
    dispositionRevision.value = dispositionRevision.value + 1;
  }

  static String _key(String userId, String suffix) =>
      '$_prefix.$userId.$suffix';

  // ---------------------------------------------------------------------------
  // Stamping API
  // ---------------------------------------------------------------------------

  /// Stamps both `last_login` and `last_app_open` to now.
  ///
  /// `last_login` is no longer read by the disposition evaluator (the
  /// 2-signal ladder uses only app-open + session), but the stamp is kept
  /// for any future feature that wants to know when a user last
  /// authenticated.
  static Future<void> markLogin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await prefs.setString(_key(userId, 'last_login'), nowIso);
    await prefs.setString(_key(userId, 'last_app_open'), nowIso);
    _bump();
  }

  /// Stamps `last_app_open` to now.
  static Future<void> markAppOpen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId, 'last_app_open'),
      DateTime.now().toUtc().toIso8601String(),
    );
    _bump();
  }

  /// Stamps `last_session` to now, but only if [roundsCompleted] meets the
  /// qualifying threshold. Sessions that fail this gate are ignored so that
  /// zero-effort attempts don't earn Praise.
  static Future<void> markSessionCompleted(
    String userId,
    int roundsCompleted,
  ) async {
    if (roundsCompleted < kQualifyingRounds) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId, 'last_session'),
      DateTime.now().toUtc().toIso8601String(),
    );
    _bump();
  }

  // ---------------------------------------------------------------------------
  // Read API
  // ---------------------------------------------------------------------------

  static Future<DateTime?> _read(String userId, String suffix) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, suffix));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<DateTime?> getLastLogin(String userId) =>
      _read(userId, 'last_login');
  static Future<DateTime?> getLastAppOpen(String userId) =>
      _read(userId, 'last_app_open');
  static Future<DateTime?> getLastSession(String userId) =>
      _read(userId, 'last_session');

  /// Wipes all Knight state for [userId]. Call on account deletion.
  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId, 'last_login'));
    await prefs.remove(_key(userId, 'last_app_open'));
    await prefs.remove(_key(userId, 'last_session'));
    _bump();
  }

  // ---------------------------------------------------------------------------
  // Test override (in-memory only — resets on app restart)
  // ---------------------------------------------------------------------------

  static KnightDisposition? _testOverride;

  static void setTestOverride(KnightDisposition d) {
    _testOverride = d;
    _bump();
  }

  static void clearTestOverride() {
    _testOverride = null;
    _bump();
  }

  static KnightDisposition? getTestOverride() => _testOverride;

  // ---------------------------------------------------------------------------
  // Disposition evaluation
  // ---------------------------------------------------------------------------

  /// Evaluates the current disposition for [userId]. A brand-new user (no
  /// stamps yet) returns Praise as a welcoming default.
  static Future<KnightDisposition> evaluate(String userId) async {
    if (_testOverride != null) return _testOverride!;
    final lastSession = await getLastSession(userId);
    final lastAppOpen = await getLastAppOpen(userId);
    return projectDisposition(
      now: DateTime.now().toUtc(),
      lastSession: lastSession,
      lastAppOpen: lastAppOpen,
    );
  }

  /// Pure helper: derives the disposition for a hypothetical [now] given the
  /// most recent activity timestamps. Exposed so the notification scheduler
  /// can project disposition for future days when pre-scheduling.
  ///
  /// Two-signal ladder, in weight order:
  ///   1. First-run welcome → Praise when both timestamps are null.
  ///   2. Praise override — a qualifying session within [kPraiseWindow]
  ///      always wins, regardless of how recent app-open is.
  ///   3. Walk the ladder: prefer `lastAppOpen`, fall back to `lastSession`
  ///      when app-open is missing. Apply the standard age windows:
  ///        ≤ 48h          → Questioned
  ///        48h – 7d       → Concerned
  ///        ≥ 7d           → Inactive
  ///   4. Defensive fall-through (both null after step 1) → Inactive.
  static KnightDisposition projectDisposition({
    required DateTime now,
    required DateTime? lastSession,
    required DateTime? lastAppOpen,
  }) {
    // 1. First-run welcome.
    if (lastSession == null && lastAppOpen == null) {
      return KnightDisposition.praise;
    }

    // 2. Praise: qualifying session within the praise window.
    if (lastSession != null && now.difference(lastSession) <= kPraiseWindow) {
      return KnightDisposition.praise;
    }

    // 3. Pick the highest-weight available timestamp.
    final reference = lastAppOpen ?? lastSession;
    if (reference == null) {
      // 4. Defensive: should be unreachable given step 1.
      return KnightDisposition.inactive;
    }

    final age = now.difference(reference);

    if (age >= kInactiveThreshold) {
      return KnightDisposition.inactive;
    }
    if (age <= kQuestionedWindow) {
      return KnightDisposition.questioned;
    }
    // Anything between Questioned and Inactive is Concerned.
    return KnightDisposition.concerned;
  }

  /// Returns a random dialogue line for [disposition]. A fresh selection on
  /// every call ensures the home screen rotates lines on each load.
  static String pickRandomLine(KnightDisposition disposition, {Random? rng}) {
    final lines = disposition.lines;
    final r = rng ?? Random();
    return lines[r.nextInt(lines.length)];
  }
}
