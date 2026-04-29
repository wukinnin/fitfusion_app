import 'dart:math';

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
  static const Duration kPraiseWindow = Duration(hours: 24);
  static const Duration kQuestionedAppOpenWindow = Duration(hours: 48);
  static const Duration kConcernedMin = Duration(hours: 48);
  static const Duration kConcernedMax = Duration(hours: 72);
  static const Duration kInactiveThreshold = Duration(days: 7);

  static String _key(String userId, String suffix) =>
      '$_prefix.$userId.$suffix';

  // ---------------------------------------------------------------------------
  // Stamping API
  // ---------------------------------------------------------------------------

  /// Stamps both `last_login` and `last_app_open` to now.
  static Future<void> markLogin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await prefs.setString(_key(userId, 'last_login'), nowIso);
    await prefs.setString(_key(userId, 'last_app_open'), nowIso);
  }

  /// Stamps `last_app_open` to now.
  static Future<void> markAppOpen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId, 'last_app_open'),
      DateTime.now().toUtc().toIso8601String(),
    );
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
  }

  // ---------------------------------------------------------------------------
  // Test override (in-memory only — resets on app restart)
  // ---------------------------------------------------------------------------

  static KnightDisposition? _testOverride;

  static void setTestOverride(KnightDisposition d) => _testOverride = d;
  static void clearTestOverride() => _testOverride = null;
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
  static KnightDisposition projectDisposition({
    required DateTime now,
    required DateTime? lastSession,
    required DateTime? lastAppOpen,
  }) {
    // First-run welcome.
    if (lastSession == null && lastAppOpen == null) {
      return KnightDisposition.praise;
    }

    // Praise: qualifying session within last 24h.
    if (lastSession != null && now.difference(lastSession) <= kPraiseWindow) {
      return KnightDisposition.praise;
    }

    // App-open metric drives the rest.
    if (lastAppOpen == null) {
      return KnightDisposition.inactive;
    }

    final sinceOpen = now.difference(lastAppOpen);

    // Inactive: 7+ days with no app open.
    if (sinceOpen >= kInactiveThreshold) {
      return KnightDisposition.inactive;
    }

    // Concerned: 48–72h without an app open.
    if (sinceOpen >= kConcernedMin) {
      return KnightDisposition.concerned;
    }

    // Questioned: app opened within last 48h, but no qualifying session.
    if (sinceOpen <= kQuestionedAppOpenWindow) {
      return KnightDisposition.questioned;
    }

    // Fallthrough — should be unreachable, but default to concerned.
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
