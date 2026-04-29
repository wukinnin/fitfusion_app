import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../features/knight/knight_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../widgets/fitfusion_animated_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Stamp app-open + refresh the next 7 days of Knight pings so the
        // projected disposition stays current.
        await KnightService.markAppOpen(user.id);
        // Fire and forget — don't block navigation on scheduling.
        // ignore: unawaited_futures
        NotificationService.instance.rescheduleKnightPings(user.id);

        // Warm the username/email cache so the UserProfileFooter renders
        // synchronously on the very first home-screen frame. This is what
        // kills the post-splash header pop-in.
        await UserService.preload();

        if (!mounted) return;
        final forceReset = user.userMetadata?['force_password_reset'] == true;
        if (forceReset) {
          Navigator.pushReplacementNamed(context, '/auth/reset-password');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      body: FitFusionAnimatedBackground(
        child: Center(
          child: Text(
            'FitFusion',
            style: GoogleFonts.cinzelDecorative(
              color: AppTheme.gold,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
