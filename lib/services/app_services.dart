import 'package:flutter/widgets.dart';

import '../features/achievements/achievement_service.dart';
import 'auth_service.dart';
import 'leaderboard_service.dart';
import 'session_service.dart';
import 'stats_service.dart';
import 'user_settings_service.dart';

class AppServices {
  final AuthService authService;
  final SessionService sessionService;
  final AchievementServiceBase achievementService;
  final StatsService statsService;
  final LeaderboardService leaderboardService;
  final UserSettingsService userSettingsService;

  AppServices({
    required this.authService,
    required this.sessionService,
    required this.achievementService,
    required this.statsService,
    required this.leaderboardService,
    required this.userSettingsService,
  });

  factory AppServices.defaults() {
    return AppServices(
      authService: SupabaseAuthService(),
      sessionService: SupabaseSessionService(),
      achievementService: AchievementService(),
      statsService: SupabaseStatsService(),
      leaderboardService: SupabaseLeaderboardService(),
      userSettingsService: SupabaseUserSettingsService(),
    );
  }
}

class AppServicesScope extends InheritedWidget {
  final AppServices services;

  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope not found in widget tree.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(covariant AppServicesScope oldWidget) {
    return oldWidget.services != services;
  }
}
