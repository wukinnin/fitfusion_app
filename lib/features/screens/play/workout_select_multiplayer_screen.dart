import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums.dart';
import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';
import '../../../widgets/user_profile_footer.dart';
import 'tutorial_popup.dart';

/// Multiplayer workout picker. Currently only Jumping Jacks is supported;
/// the other two are rendered disabled with a small "MULTIPLAYER ONLY: JJ"
/// affordance.
class WorkoutSelectMultiplayerScreen extends StatelessWidget {
  const WorkoutSelectMultiplayerScreen({super.key});

  void _onJumpingJacksSelected(BuildContext context) {
    showWorkoutTutorialIfNeeded(
      context,
      onConfirm: () {
        if (!context.mounted) return;
        Navigator.pushNamed(
          context,
          '/multiplayer/p2-email',
          arguments: {'workoutType': WorkoutType.jumpingJacks},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      appBar: AppBar(
        backgroundColor: AppTheme.bloodRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MULTIPLAYER',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FitFusionAnimatedBackground(
        child: Column(
          children: [
            const UserProfileFooter(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Multiplayer is currently limited\nto Jumping Jacks.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: AppTheme.creamWhite.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _WorkoutButton(
                        title: 'Squats',
                        enabled: false,
                        onPressed: () {},
                      ),
                      const SizedBox(height: 16),
                      _WorkoutButton(
                        title: 'Jumping Jacks',
                        enabled: true,
                        onPressed: () => _onJumpingJacksSelected(context),
                      ),
                      const SizedBox(height: 16),
                      _WorkoutButton(
                        title: 'Side Crunches',
                        enabled: false,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutButton extends StatelessWidget {
  final String title;
  final bool enabled;
  final VoidCallback onPressed;

  const _WorkoutButton({
    required this.title,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled
            ? AppTheme.gold
            : AppTheme.gold.withValues(alpha: 0.25),
        foregroundColor: AppTheme.bloodRed,
        disabledBackgroundColor: AppTheme.gold.withValues(alpha: 0.18),
        disabledForegroundColor: AppTheme.bloodRed.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
