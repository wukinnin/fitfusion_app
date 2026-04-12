import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'services/app_services.dart';
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

class FitFusionApp extends StatelessWidget {
  const FitFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: AppServices.defaults(),
      child: MaterialApp(
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
          '/settings/reset-password': (context) => const ResetPasswordSettingsScreen(),
          '/settings/change-username': (context) => const ChangeUsernameScreen(),
          '/settings/change-email': (context) => const ChangeEmailScreen(),
          '/settings/delete-account': (context) => const DeleteAccountScreen(),
        },
      ),
    );
  }
}
