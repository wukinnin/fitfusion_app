import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/screens/achievements_screen.dart';
import 'features/screens/auth/auth_landing_screen.dart';
import 'features/screens/auth/login_screen.dart';
import 'features/screens/auth/reset_password_screen.dart';
import 'features/screens/auth/signup_screen.dart';
import 'features/screens/auth/verify_email_screen.dart';
import 'features/screens/game_screen.dart';
import 'features/screens/home_screen.dart';
import 'features/screens/leaderboard_screen.dart';
import 'features/screens/results_screen.dart';
import 'features/screens/splash_screen.dart';
import 'features/screens/stats_screen.dart';
import 'features/screens/workout_select_screen.dart';

class FitFusionApp extends StatelessWidget {
  const FitFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFusion',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthLandingScreen(),
        '/auth/login': (context) => const LoginScreen(),
        '/auth/signup': (context) => const SignupScreen(),
        '/auth/verify': (context) => const VerifyEmailScreen(),
        '/auth/reset-password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/select': (context) => const WorkoutSelectScreen(),
        '/game': (context) => const GameScreen(),
        '/results': (context) => const ResultsScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/stats': (context) => const StatsScreen(),
        '/achievements': (context) => const AchievementsScreen(),
      },
    );
  }
}
