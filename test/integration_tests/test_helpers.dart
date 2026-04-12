import 'package:fitfusion/core/enums.dart';
import 'package:fitfusion/features/achievements/achievement_service.dart';
import 'package:fitfusion/features/game/game_session.dart';
import 'package:fitfusion/services/app_services.dart';
import 'package:fitfusion/services/auth_service.dart';
import 'package:fitfusion/services/leaderboard_service.dart';
import 'package:fitfusion/services/session_service.dart';
import 'package:fitfusion/services/stats_service.dart';
import 'package:fitfusion/services/user_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IntegrationStore {
  final List<GameSession> sessions = [];
}

class FakeAuthService implements AuthService {
  FakeAuthService({
    this.loginNeedsVerification = false,
    this.changeEmailNeedsVerification = false,
    AuthUser? currentUser,
  }) : _currentUser = currentUser;

  bool loginNeedsVerification;
  bool changeEmailNeedsVerification;
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  bool get hasActiveSession => _currentUser != null;

  @override
  Future<SignupResult> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    return SignupResult(email: email);
  }

  @override
  Future<VerifyResult> verifyEmail({
    required String email,
    required String code,
    required String type,
  }) async {
    if (type == 'recovery') {
      return VerifyResult.resetPassword(email: email);
    }
    _currentUser = AuthUser(id: 'user-1', email: email, isEmailVerified: true);
    return const VerifyResult.login();
  }

  @override
  Future<void> resendVerificationCode({
    required String email,
    required String type,
  }) async {}

  @override
  Future<LoginResult> login({
    required String identifier,
    required String password,
  }) async {
    if (loginNeedsVerification) {
      return LoginResult.verify(
        email: identifier.contains('@') ? identifier : 'resolved@example.com',
      );
    }
    _currentUser = AuthUser(
      id: 'user-1',
      email: identifier.contains('@') ? identifier : 'resolved@example.com',
      isEmailVerified: true,
    );
    return const LoginResult.home();
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword(String newPassword) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> changeUsername({
    required String currentPassword,
    required String newUsername,
  }) async {}

  @override
  Future<ChangeEmailResult> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    if (changeEmailNeedsVerification) {
      return ChangeEmailResult(
        requiresVerification: true,
        email: newEmail,
      );
    }
    _currentUser = AuthUser(id: 'user-1', email: newEmail, isEmailVerified: true);
    return ChangeEmailResult(
      requiresVerification: false,
      email: newEmail,
    );
  }

  @override
  Future<void> deleteAccount(String currentPassword) async {
    _currentUser = null;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

class FakeSessionService implements SessionService {
  FakeSessionService(this.store);

  final IntegrationStore store;

  @override
  Future<void> saveSession(GameSession session) async {
    store.sessions.add(session);
  }
}

class FakeAchievementService implements AchievementServiceBase {
  FakeAchievementService(this.store);

  final IntegrationStore store;
  final Set<AchievementId> _unlocked = {};

  @override
  Future<void> init() async {
    _unlocked
      ..clear()
      ..addAll(_deriveUnlocks());
  }

  @override
  bool isUnlocked(AchievementId id) => _unlocked.contains(id);

  @override
  Set<AchievementId> get unlockedAchievements => _unlocked;

  @override
  Future<List<AchievementId>> evaluateSession(GameSession session) async {
    final before = Set<AchievementId>.from(_unlocked);
    store.sessions.add(session);
    _unlocked
      ..clear()
      ..addAll(_deriveUnlocks());
    return _unlocked.difference(before).toList();
  }

  Set<AchievementId> _deriveUnlocks() {
    final result = <AchievementId>{};
    if (store.sessions.isNotEmpty) {
      result.add(AchievementId.firstBlood);
    }
    if (store.sessions.any((session) => session.won)) {
      result.add(AchievementId.monsterHunter);
    }
    return result;
  }
}

class FakeStatsService implements StatsService {
  FakeStatsService(this.store);

  final IntegrationStore store;

  @override
  Future<StatsData> fetchStats() async {
    final workoutStats = [
      _buildWorkoutStats(WorkoutType.squats),
      _buildWorkoutStats(WorkoutType.jumpingJacks),
      _buildWorkoutStats(WorkoutType.obliqueCrunches),
    ];

    final totalSessions = store.sessions.length;
    final totalReps = store.sessions.fold<int>(0, (sum, s) => sum + s.totalReps);
    final totalRounds =
        store.sessions.fold<int>(0, (sum, s) => sum + s.roundsCompleted);
    final totalVictories =
        store.sessions.where((session) => session.won).length;

    return StatsData(
      workoutStats: workoutStats,
      overallStats: {
        'totalSessions': totalSessions.toString(),
        'totalReps': totalReps.toString(),
        'totalRounds': totalRounds.toString(),
        'totalVictories': totalVictories.toString(),
      },
    );
  }

  Map<String, String> _buildWorkoutStats(WorkoutType type) {
    final sessions =
        store.sessions.where((session) => session.workoutType == type).toList();
    if (sessions.isEmpty) {
      return {
        'fastestClearTime': '--',
        'avgClearTime': '--',
        'bestRepInterval': '--',
        'avgRepInterval': '--',
        'roundsCompleted': '0',
        'repsFinished': '0',
        'victories': '0',
        'defeats': '0',
      };
    }

    final wonSessions = sessions.where((session) => session.won).toList();
    final fastestClearTime = wonSessions.isEmpty
        ? '--'
        : _formatTime(wonSessions
            .map((s) => s.totalTimeSeconds)
            .reduce((a, b) => a < b ? a : b));
    final avgClearTime = wonSessions.length < 2
        ? '--'
        : _formatTime(
            wonSessions
                    .map((s) => s.totalTimeSeconds)
                    .reduce((a, b) => a + b) /
                wonSessions.length,
          );
    final bestRepInterval = sessions
            .where((session) => session.bestRepIntervalSeconds > 0)
            .isEmpty
        ? '--'
        : _formatInterval(sessions
            .where((session) => session.bestRepIntervalSeconds > 0)
            .map((s) => s.bestRepIntervalSeconds)
            .reduce((a, b) => a < b ? a : b));
    final avgIntervals = sessions
        .where((session) => session.avgRepIntervalSeconds > 0)
        .map((s) => s.avgRepIntervalSeconds)
        .toList();
    final avgRepInterval = avgIntervals.length < 2
        ? '--'
        : _formatInterval(avgIntervals.reduce((a, b) => a + b) / avgIntervals.length);

    return {
      'fastestClearTime': fastestClearTime,
      'avgClearTime': avgClearTime,
      'bestRepInterval': bestRepInterval,
      'avgRepInterval': avgRepInterval,
      'roundsCompleted':
          sessions.fold<int>(0, (sum, s) => sum + s.roundsCompleted).toString(),
      'repsFinished':
          sessions.fold<int>(0, (sum, s) => sum + s.totalReps).toString(),
      'victories': wonSessions.length.toString(),
      'defeats': sessions.where((session) => !session.won).length.toString(),
    };
  }

  String _formatTime(double totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  String _formatInterval(double seconds) => '${seconds.toStringAsFixed(3)}s';
}

class FakeLeaderboardService implements LeaderboardService {
  FakeLeaderboardService(this.store);

  final IntegrationStore store;

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchLeaderboards() async {
    final result = <String, List<Map<String, dynamic>>>{};
    final workouts = [
      WorkoutType.squats,
      WorkoutType.jumpingJacks,
      WorkoutType.obliqueCrunches,
    ];

    for (int i = 0; i < workouts.length; i++) {
      final sessions =
          store.sessions.where((session) => session.workoutType == workouts[i]).toList();
      final clearTimeSessions = sessions.where((session) => session.won).toList()
        ..sort((a, b) => a.totalTimeSeconds.compareTo(b.totalTimeSeconds));
      result['$i:0'] = List.generate(clearTimeSessions.length, (index) {
        final session = clearTimeSessions[index];
        return {
          'rank': index + 1,
          'username': 'TestUser',
          'value': session.totalTimeSeconds,
        };
      });

      final bestIntervalSessions = sessions.toList()
        ..sort((a, b) =>
            a.bestRepIntervalSeconds.compareTo(b.bestRepIntervalSeconds));
      result['$i:1'] = List.generate(bestIntervalSessions.length, (index) {
        final session = bestIntervalSessions[index];
        return {
          'rank': index + 1,
          'username': 'TestUser',
          'value': session.bestRepIntervalSeconds,
        };
      });
    }

    final totalReps = store.sessions.fold<int>(0, (sum, s) => sum + s.totalReps);
    final totalVictories = store.sessions.where((session) => session.won).length;
    result['3:0'] = totalReps == 0
        ? []
        : [
            {'rank': 1, 'username': 'TestUser', 'value': totalReps}
          ];
    result['3:1'] = totalVictories == 0
        ? []
        : [
            {'rank': 1, 'username': 'TestUser', 'value': totalVictories}
          ];
    return result;
  }
}

class FakeUserSettingsService implements UserSettingsService {
  bool showTutorial;

  FakeUserSettingsService({this.showTutorial = true});

  @override
  Future<bool> loadShowTutorial() async => showTutorial;

  @override
  Future<void> updateShowTutorial(bool value) async {
    showTutorial = value;
  }
}

Widget buildIntegrationApp({
  required AppServices services,
  Widget? home,
  Map<String, WidgetBuilder> routes = const {},
  RouteFactory? onGenerateRoute,
  String? initialRoute,
}) {
  GoogleFonts.config.allowRuntimeFetching = false;

  return AppServicesScope(
    services: services,
    child: MaterialApp(
      home: home,
      routes: routes,
      onGenerateRoute: onGenerateRoute,
      initialRoute: initialRoute,
    ),
  );
}

class TargetScreen extends StatelessWidget {
  final String label;

  const TargetScreen(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class RoutedArgsScreen extends StatelessWidget {
  const RoutedArgsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      body: Center(child: Text(args.toString())),
    );
  }
}

GameSession sampleSession({
  WorkoutType workoutType = WorkoutType.squats,
  bool won = true,
  int totalReps = 20,
  double totalTimeSeconds = 75.5,
}) {
  return GameSession(
    workoutType: workoutType,
    won: won,
    totalReps: totalReps,
    totalRepsRequired: totalReps,
    totalTimeSeconds: totalTimeSeconds,
    roundsCompleted: won ? 10 : 5,
    bestRepIntervalSeconds: 1.7,
    avgRepIntervalSeconds: 2.2,
    livesLost: won ? 0 : 2,
    completedAt: DateTime(2026, 4, 12),
  );
}

AppServices makeFakeServices({
  required IntegrationStore store,
  FakeAuthService? authService,
  FakeUserSettingsService? userSettingsService,
}) {
  return AppServices(
    authService: authService ?? FakeAuthService(),
    sessionService: FakeSessionService(store),
    achievementService: FakeAchievementService(store),
    statsService: FakeStatsService(store),
    leaderboardService: FakeLeaderboardService(store),
    userSettingsService: userSettingsService ?? FakeUserSettingsService(),
  );
}
