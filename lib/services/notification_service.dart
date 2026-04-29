import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../features/knight/knight_disposition.dart';
import '../features/knight/knight_service.dart';

/// Schedules the Fitness Knight's daily pings via OS-level local
/// notifications. Two pings per day:
///   - 08:00 local: the daily greeting (always fires).
///   - 19:00 local: a same-day follow-up that is suppressed on any day the
///     user has already opened the app at least once.
///
/// Suppression is implemented at *scheduling* time (no background isolate):
/// every call to [rescheduleKnightPings] cancels the full pending set and
/// re-schedules from scratch, dropping today's 19:00 slot when
/// `lastAppOpen` lands on the current local calendar day. Existing call
/// sites already invoke reschedule after every `markLogin` /
/// `markAppOpen` / `markSessionCompleted`, so the suppression fires the
/// moment the user engages.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'knight_daily_ping';
  static const String _channelName = 'Fitness Knight';
  static const String _channelDesc =
      'Daily reminders from your Fitness Knight.';

  /// Local-time hours at which the morning and evening pings fire.
  /// These are re-exported from KnightService so the in-app dialogue
  /// picker and the scheduler agree on the slot boundaries.
  static const int kMorningHour = KnightService.kMorningHour;
  static const int kEveningHour = KnightService.kEveningHour;
  static const int kSlotMinute = 0;

  /// How many days out to pre-schedule (today + next N).
  static const int kHorizonDays = 7;

  /// Notification ID bases. Day offsets (0..kHorizonDays) are added so each
  /// pending notification has a stable, individually-cancellable id.
  ///   morning: 1000 + dayOffset
  ///   evening: 1100 + dayOffset
  static const int _morningIdBase = 1000;
  static const int _eveningIdBase = 1100;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Create the channel up-front so the OS has it before the first schedule.
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.defaultImportance,
        ),
      );
      // Best-effort runtime permission requests (Android 13+).
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Cancels and re-schedules the rolling `today + kHorizonDays` window of
  /// Knight pings for [userId]. Each notification's body is computed at
  /// scheduling time based on the disposition projected for that future
  /// date (assuming no further activity between now and then).
  ///
  /// Today's 19:00 evening ping is dropped when the user has already opened
  /// the app today (per `lastAppOpen`) — this is the "already engaged,
  /// don't bug me again" rule.
  Future<void> rescheduleKnightPings(String userId) async {
    if (!_initialized) await initialize();

    await cancelAll();

    final lastAppOpen = await KnightService.getLastAppOpen(userId);
    final recentSessions = await KnightService.getRecentSessions(userId);

    final nowLocal = tz.TZDateTime.now(tz.local);
    final engagedToday =
        lastAppOpen != null && _isSameLocalDay(lastAppOpen, nowLocal);

    int scheduled = 0;
    int suppressed = 0;

    for (int dayOffset = 0; dayOffset <= kHorizonDays; dayOffset++) {
      final isToday = dayOffset == 0;
      final morning = _slotAt(nowLocal, dayOffset, KnightPingSlot.morning);
      final evening = _slotAt(nowLocal, dayOffset, KnightPingSlot.evening);

      // ---- Morning slot --------------------------------------------------
      if (morning.isAfter(nowLocal)) {
        final projected = KnightService.projectDisposition(
          now: morning.toUtc(),
          lastAppOpen: lastAppOpen,
          recentSessions: recentSessions,
        );
        await _scheduleOne(
          id: _morningIdBase + dayOffset,
          title: _titleFor(projected, KnightPingSlot.morning),
          body: KnightService.pickLineFor(
            disposition: projected,
            dateLocal: morning,
            slot: KnightPingSlot.morning,
          ),
          when: morning,
        );
        scheduled++;
      }

      // ---- Evening slot --------------------------------------------------
      if (!evening.isAfter(nowLocal)) {
        // already in the past — nothing to do
      } else if (isToday && engagedToday) {
        // suppressed: user has already opened the app today
        suppressed++;
      } else {
        final projected = KnightService.projectDisposition(
          now: evening.toUtc(),
          lastAppOpen: lastAppOpen,
          recentSessions: recentSessions,
        );
        await _scheduleOne(
          id: _eveningIdBase + dayOffset,
          title: _titleFor(projected, KnightPingSlot.evening),
          body: KnightService.pickLineFor(
            disposition: projected,
            dateLocal: evening,
            slot: KnightPingSlot.evening,
          ),
          when: evening,
        );
        scheduled++;
      }
    }

    assert(() {
      debugPrint(
        '[NotificationService] Rescheduled $scheduled Knight pings for $userId '
        '(suppressed $suppressed evening slot${suppressed == 1 ? '' : 's'})',
      );
      return true;
    }());
  }

  /// Sends an immediate test notification (not scheduled) using the given
  /// [disposition]. Uses the same title/body format as the real daily
  /// pings — including the deterministic slot-based line picker, so the
  /// test notification matches what the home-screen bubble currently
  /// shows for that disposition.
  Future<void> sendTestNotification(KnightDisposition disposition) async {
    if (!_initialized) await initialize();

    final slotInfo = KnightService.currentSlotFor(DateTime.now());
    final line = KnightService.pickLineFor(
      disposition: disposition,
      dateLocal: slotInfo.date,
      slot: slotInfo.slot,
    );
    final title = _titleFor(disposition, slotInfo.slot);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      9999, // Test notification ID
      title,
      line,
      details,
    );

    assert(() {
      debugPrint(
        '[NotificationService] Test notification sent: $title — $line',
      );
      return true;
    }());
  }

  Future<void> cancelAll() async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Builds a TZDateTime at the requested slot of the local day that is
  /// `dayOffset` days from `nowLocal`. Constructing via `TZDateTime(...)`
  /// directly (rather than adding a Duration) keeps the wall-clock hour
  /// stable across DST boundaries.
  tz.TZDateTime _slotAt(
    tz.TZDateTime nowLocal,
    int dayOffset,
    KnightPingSlot slot,
  ) {
    final hour =
        slot == KnightPingSlot.morning ? kMorningHour : kEveningHour;
    final base = tz.TZDateTime(
      tz.local,
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + dayOffset,
      hour,
      kSlotMinute,
    );
    return base;
  }

  bool _isSameLocalDay(DateTime a, tz.TZDateTime b) {
    final aLocal = tz.TZDateTime.from(a, tz.local);
    return aLocal.year == b.year &&
        aLocal.month == b.month &&
        aLocal.day == b.day;
  }

  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  String _titleFor(KnightDisposition disposition, KnightPingSlot slot) {
    if (slot == KnightPingSlot.morning) {
      switch (disposition) {
        case KnightDisposition.veryActive:
          return 'Your Knight salutes you ⚔️';
        case KnightDisposition.somewhatActive:
          return 'Your Knight stands ready 🛡️';
        case KnightDisposition.neutral:
          return 'Your Knight is waiting...';
        case KnightDisposition.somewhatInactive:
          return 'Your Knight grows uneasy';
        case KnightDisposition.veryInactive:
          return 'Your Knight has gone quiet';
      }
    }
    // Evening — "calls again" framing so users can distinguish back-to-back
    // notifications at a glance.
    switch (disposition) {
      case KnightDisposition.veryActive:
        return 'Your Knight raises a toast 🍻';
      case KnightDisposition.somewhatActive:
        return 'Your Knight calls again ⚔️';
      case KnightDisposition.neutral:
        return 'Your Knight calls again...';
      case KnightDisposition.somewhatInactive:
        return 'Your Knight broods alone';
      case KnightDisposition.veryInactive:
        return 'Your Knight stands alone';
    }
  }
}
