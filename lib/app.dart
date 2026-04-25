import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'features/screens/achievements_screen.dart';
import 'features/screens/auth/auth_landing_screen.dart';
import 'features/screens/auth/forgot_password_screen.dart';
import 'features/screens/auth/login_screen.dart';
import 'features/screens/auth/reset_password_screen.dart';
import 'features/screens/auth/signup_screen.dart';
import 'features/screens/auth/verify_email_screen.dart';
import 'features/screens/game_screen.dart';
import 'features/screens/home_screen.dart';
import 'features/screens/leaderboard_screen.dart';
import 'features/screens/results_screen.dart';
import 'features/screens/settings/change_email_screen.dart';
import 'features/screens/settings/change_username_screen.dart';
import 'features/screens/settings/delete_account_screen.dart';
import 'features/screens/settings/edit_profile_screen.dart';
import 'features/screens/settings/reset_password_settings_screen.dart';
import 'features/screens/settings_screen.dart';
import 'features/screens/splash_screen.dart';
import 'features/screens/stats_screen.dart';
import 'features/screens/workout_select_screen.dart';
import 'services/app_bgm_service.dart';

final AppBgmRouteObserver _appBgmRouteObserver = AppBgmRouteObserver();

class FitFusionApp extends StatefulWidget {
  const FitFusionApp({super.key});

  @override
  State<FitFusionApp> createState() => _FitFusionAppState();
}

class _FitFusionAppState extends State<FitFusionApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;

      if (event == AuthChangeEvent.signedOut) {
        // Force redirect to auth landing if session is lost
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/auth',
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'FitFusion',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      navigatorObservers: [_appBgmRouteObserver],
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthLandingScreen(),
        '/auth/login': (context) => const LoginScreen(),
        '/auth/signup': (context) => const SignupScreen(),
        '/auth/verify': (context) => const VerifyEmailScreen(),
        '/auth/forgot-password': (context) => const ForgotPasswordScreen(),
        '/auth/reset-password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/select': (context) => const WorkoutSelectScreen(),
        '/game': (context) => const GameScreen(),
        '/results': (context) => const ResultsScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/stats': (context) => const StatsScreen(),
        '/achievements': (context) => const AchievementsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings/edit-profile': (context) => const EditProfileScreen(),
        '/settings/reset-password': (context) =>
            const ResetPasswordSettingsScreen(),
        '/settings/change-username': (context) => const ChangeUsernameScreen(),
        '/settings/change-email': (context) => const ChangeEmailScreen(),
        '/settings/delete-account': (context) => const DeleteAccountScreen(),
      },
    );
  }
}
