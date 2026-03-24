import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/auth');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      body: Center(
        child: Text(
          'FitFusion',
          style: TextStyle(
            color: AppTheme.gold,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cinzel',
          ),
        ),
      ),
    );
  }
}
