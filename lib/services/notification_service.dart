import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../features/knight/knight_disposition.dart';
import '../features/knight/knight_service.dart';

/// Schedules the daily 10:00 Fitness Knight ping(s) using OS-level scheduled
/// delivery. No background isolate, no workmanager — pre-schedules the next
/// 7 days as individual notifications, each with content baked in based on
/// the disposition projected for that future date.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'knight_daily_ping';
  static const String _channelName = 'Fitness Knight';
  static const String _channelDesc =
      'Daily reminders from your Fitness Knight.';

  /// Hour of day (local) at which the daily notification fires.
  static const int kDailyHour = 10;
  static const int kDailyMinute = 0;

  /// How many days out to pre-schedule.
  static const int kHorizonDays = 7;

  /// Notification ID base. Day offsets (1..kHorizonDays) are added so each
  /// pending notification has a stable, individually-cancellable id.
  static const int _idBase = 1000;

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

  /// Cancels and re-schedules the next [kHorizonDays] daily Knight pings for
  /// [userId]. Each notification's body is computed at scheduling time based
  /// on the disposition projected for that future date (assuming no further
  /// activity between now and then).
  Future<void> rescheduleKnightPings(String userId) async {
    if (!_initialized) await initialize();

    await cancelAll();

    final lastSession = await KnightService.getLastSession(userId);
    final lastAppOpen = await KnightService.getLastAppOpen(userId);

    final nowLocal = tz.TZDateTime.now(tz.local);

    for (int dayOffset = 1; dayOffset <= kHorizonDays; dayOffset++) {
      final fireDate = _next10amAtOffset(nowLocal, dayOffset);

      final projected = KnightService.projectDisposition(
        now: fireDate.toUtc(),
        lastSession: lastSession,
        lastAppOpen: lastAppOpen,
      );
      final line = KnightService.pickRandomLine(projected);

      await _scheduleOne(
        id: _idBase + dayOffset,
        title: _titleFor(projected),
        body: line,
        when: fireDate,
      );
    }

    assert(() {
      debugPrint(
        '[NotificationService] Rescheduled $kHorizonDays Knight pings for $userId',
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

  tz.TZDateTime _next10amAtOffset(tz.TZDateTime nowLocal, int dayOffset) {
    final base = tz.TZDateTime(
      tz.local,
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      kDailyHour,
      kDailyMinute,
    );
    return base.add(Duration(days: dayOffset));
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

  String _titleFor(KnightDisposition disposition) {
    switch (disposition) {
      case KnightDisposition.praise:
        return 'Your Knight salutes you ⚔️';
      case KnightDisposition.questioned:
        return 'Your Knight is waiting...';
      case KnightDisposition.concerned:
        return 'Your Knight is worried';
      case KnightDisposition.inactive:
        return 'Your Knight has gone quiet';
    }
  }
}
