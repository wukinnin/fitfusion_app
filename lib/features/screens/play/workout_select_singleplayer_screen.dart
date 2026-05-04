import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums.dart';
import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';
import '../../../widgets/user_profile_footer.dart';

/// Singleplayer workout picker — squats / jumping jacks / side crunches.
/// The tutorial popup is deferred to the cooldown screen's BEGIN button so
/// it shows right before the game session starts.
class WorkoutSelectSingleplayerScreen extends StatelessWidget {
  const WorkoutSelectSingleplayerScreen({super.key});

  void _onWorkoutSelected(BuildContext context, WorkoutType type) {
    Navigator.pushNamed(
      context,
      '/select/cooldown',
      arguments: {
        'workoutType': type,
        'isMultiplayer': false,
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
          'CHOOSE YOUR BATTLE',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 20,
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
                      _WorkoutButton(
                        title: 'Squats',
                        onPressed: () =>
                            _onWorkoutSelected(context, WorkoutType.squats),
                      ),
                      const SizedBox(height: 16),
                      _WorkoutButton(
                        title: 'Jumping Jacks',
                        onPressed: () => _onWorkoutSelected(
                          context,
                          WorkoutType.jumpingJacks,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WorkoutButton(
                        title: 'Side Crunches',
                        onPressed: () => _onWorkoutSelected(
                          context,
                          WorkoutType.obliqueCrunches,
                        ),
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
  final VoidCallback onPressed;

  const _WorkoutButton({required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.bloodRed,
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
