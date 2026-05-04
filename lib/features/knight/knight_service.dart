import 'dart:convert';
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
  // toward the active-tier dispositions. Prevents zero-effort sessions
  // from earning the Knight's praise.
  static const int kQualifyingRounds = 3;

  // Disposition window thresholds. See `projectDisposition` for how they
  // compose into the 5-tier ladder.
  static const Duration kVeryActiveWindow = Duration(hours: 12);
  static const Duration kSomewhatActiveWindow = Duration(hours: 24);
  static const Duration kNeutralWindow = Duration(hours: 48);
  static const Duration kSomewhatInactiveWindow = Duration(hours: 72);

  // Number of qualifying sessions in the last [kVeryActiveWindow] required
  // to bump the user to [KnightDisposition.veryActive].
  static const int kVeryActiveSessionCount = 2;

  /// Wall-clock hours (local time) at which the morning and evening Knight
  /// pings fire. Defined here (rather than in NotificationService) so that
  /// in-app dialogue selection can re-derive the "current slot" using the
  /// exact same boundaries the scheduler uses.
  static const int kMorningHour = 8;
  static const int kEveningHour = 19;

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

  /// Records a completed session, but only if [roundsCompleted] meets the
  /// qualifying threshold. Sessions that fail this gate are ignored so that
  /// zero-effort attempts don't earn an active-tier disposition.
  ///
  /// Persists to two keys:
  ///   - `last_session` — single most recent timestamp (kept for any future
  ///     consumer that just needs the latest).
  ///   - `recent_sessions` — JSON list of ISO timestamps within the last
  ///     [kSomewhatActiveWindow], pruned on each write so the list stays
  ///     bounded. The 5-tier evaluator reads this list directly.
  static Future<void> markSessionCompleted(
    String userId,
    int roundsCompleted,
  ) async {
    if (roundsCompleted < kQualifyingRounds) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    await prefs.setString(_key(userId, 'last_session'), nowIso);

    // Append to the recent-sessions list and prune anything beyond the
    // 24h window (the longest active-tier window).
    final cutoff = now.subtract(kSomewhatActiveWindow);
    final existing = _parseSessionList(
      prefs.getString(_key(userId, 'recent_sessions')),
    );
    final pruned = [
      now,
      ...existing.where((t) => t.isAfter(cutoff)),
    ];
    await prefs.setString(
      _key(userId, 'recent_sessions'),
      jsonEncode(pruned.map((t) => t.toIso8601String()).toList()),
    );

    _bump();
  }

  /// Decodes the stored JSON array of ISO timestamps. Tolerates corrupt /
  /// missing data by returning an empty list.
  static List<DateTime> _parseSessionList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <DateTime>[];
      for (final item in decoded) {
        if (item is String) {
          final t = DateTime.tryParse(item);
          if (t != null) out.add(t);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
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

  /// Returns the persisted list of recent qualifying-session timestamps
  /// (UTC). May contain entries up to [kSomewhatActiveWindow] old; callers
  /// should filter further as needed.
  static Future<List<DateTime>> getRecentSessions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _parseSessionList(
      prefs.getString(_key(userId, 'recent_sessions')),
    );
  }

  /// Wipes all Knight state for [userId]. Call on account deletion.
  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId, 'last_login'));
    await prefs.remove(_key(userId, 'last_app_open'));
    await prefs.remove(_key(userId, 'last_session'));
    await prefs.remove(_key(userId, 'recent_sessions'));
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
  /// stamps yet) returns [KnightDisposition.veryActive] as a welcoming
  /// default, matching the first-run experience.
  static Future<KnightDisposition> evaluate(String userId) async {
    if (_testOverride != null) return _testOverride!;
    final lastAppOpen = await getLastAppOpen(userId);
    final recentSessions = await getRecentSessions(userId);
    return projectDisposition(
      now: DateTime.now().toUtc(),
      lastAppOpen: lastAppOpen,
      recentSessions: recentSessions,
    );
  }

  /// Pure helper: derives the disposition for a hypothetical [now] given
  /// the latest app-open timestamp and a list of recent qualifying-session
  /// timestamps. Exposed so the notification scheduler can project the
  /// disposition for future days when pre-scheduling.
  ///
  /// 5-tier ladder, evaluated top-down:
  ///   1. First-run welcome → [veryActive] when there is no data at all.
  ///   2. ≥[kVeryActiveSessionCount] qualifying sessions in last 12h
  ///      → [veryActive].
  ///   3. ≥1 qualifying session in last 24h → [somewhatActive].
  ///   4. App-open age ≤ 48h → [neutral].
  ///   5. App-open age in (48h, 72h] → [somewhatInactive].
  ///   6. Otherwise (≥72h or missing) → [veryInactive].
  static KnightDisposition projectDisposition({
    required DateTime now,
    required DateTime? lastAppOpen,
    required List<DateTime> recentSessions,
  }) {
    // 1. First-run welcome.
    if (lastAppOpen == null && recentSessions.isEmpty) {
      return KnightDisposition.veryActive;
    }

    // 2-3. Active tiers, derived from the session history.
    final twelveHourCutoff = now.subtract(kVeryActiveWindow);
    final twentyFourHourCutoff = now.subtract(kSomewhatActiveWindow);

    int sessionsIn12h = 0;
    int sessionsIn24h = 0;
    for (final t in recentSessions) {
      if (!t.isBefore(twentyFourHourCutoff) && !t.isAfter(now)) {
        sessionsIn24h++;
        if (!t.isBefore(twelveHourCutoff)) {
          sessionsIn12h++;
        }
      }
    }

    if (sessionsIn12h >= kVeryActiveSessionCount) {
      return KnightDisposition.veryActive;
    }
    if (sessionsIn24h >= 1) {
      return KnightDisposition.somewhatActive;
    }

    // 4-6. Inactive ladder: classify by app-open recency.
    if (lastAppOpen == null) {
      // No active sessions and no app-open record → treat as fully absent.
      return KnightDisposition.veryInactive;
    }

    final openAge = now.difference(lastAppOpen);
    if (openAge <= kNeutralWindow) {
      return KnightDisposition.neutral;
    }
    if (openAge <= kSomewhatInactiveWindow) {
      return KnightDisposition.somewhatInactive;
    }
    return KnightDisposition.veryInactive;
  }

  /// Returns a random dialogue line for [disposition]. Used by callers that
  /// explicitly want a fresh roll (e.g. unit-test scaffolding). The home
  /// screen and the notification scheduler both prefer [pickLineFor] so
  /// that what the user reads in-app matches the most recent push.
  static String pickRandomLine(KnightDisposition disposition, {Random? rng}) {
    final lines = disposition.lines;
    final r = rng ?? Random();
    return lines[r.nextInt(lines.length)];
  }

  /// Deterministically picks a dialogue line for a given calendar day +
  /// slot + disposition. Two calls with the same inputs always return the
  /// same line, which lets the in-app speech bubble mirror the most
  /// recently fired push notification (and vice-versa).
  ///
  /// [dateLocal] should be a local-time [DateTime]; only the calendar
  /// date (year/month/day) is used.
  static String pickLineFor({
    required KnightDisposition disposition,
    required DateTime dateLocal,
    required KnightPingSlot slot,
  }) {
    final lines = disposition.lines;
    if (lines.isEmpty) return '';
    final h = _stableHash([
      dateLocal.year,
      dateLocal.month,
      dateLocal.day,
      slot.index,
      disposition.index,
    ]);
    return lines[h % lines.length];
  }

  /// Returns the (date, slot) pair representing the most recently fired
  /// Knight ping relative to [nowLocal]:
  ///   - hour ≥ [kEveningHour]            → today / evening
  ///   - [kMorningHour] ≤ hour < evening  → today / morning
  ///   - hour < morning                   → yesterday / evening
  ///
  /// Used by the home-screen card to show the same line the user just
  /// received in their notification.
  static ({DateTime date, KnightPingSlot slot}) currentSlotFor(
    DateTime nowLocal,
  ) {
    if (nowLocal.hour >= kEveningHour) {
      return (date: _dateOnly(nowLocal), slot: KnightPingSlot.evening);
    }
    if (nowLocal.hour >= kMorningHour) {
      return (date: _dateOnly(nowLocal), slot: KnightPingSlot.morning);
    }
    final yesterday = nowLocal.subtract(const Duration(days: 1));
    return (date: _dateOnly(yesterday), slot: KnightPingSlot.evening);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Stable, run-independent hash mixer (Dart's String.hashCode is *not*
  /// guaranteed to be stable across processes). Mixes a small list of
  /// non-negative ints into a single non-negative 31-bit int.
  static int _stableHash(List<int> parts) {
    int h = 0x12345678;
    for (final v in parts) {
      h = (h * 31 + v) & 0x7fffffff;
    }
    return h;
  }
}

/// Identifies which of the two daily Knight pings a notification belongs
/// to. Public so both [KnightService.pickLineFor] callers and the
/// notification scheduler can agree on the slot dimension.
enum KnightPingSlot { morning, evening }
