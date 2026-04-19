import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../widgets/user_profile_footer.dart';

class WorkoutSelectScreen extends StatefulWidget {
  const WorkoutSelectScreen({super.key});

  @override
  State<WorkoutSelectScreen> createState() => _WorkoutSelectScreenState();
}

class _WorkoutSelectScreenState extends State<WorkoutSelectScreen> {
  bool _showTutorialAtStartup = true;

  void _onWorkoutSelected(BuildContext context, WorkoutType type) {
    if (_showTutorialAtStartup) {
      _showTutorialPopup(context, type);
    } else {
      Navigator.pushNamed(context, '/game', arguments: type);
    }
  }

  void _showTutorialPopup(BuildContext context, WorkoutType type) {
    bool checkboxValue = _showTutorialAtStartup;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppTheme.bloodRed,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppTheme.gold, width: 2),
                  left: BorderSide(color: AppTheme.gold, width: 2),
                  right: BorderSide(color: AppTheme.gold, width: 2),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'HOW TO PLAY',
                    style: GoogleFonts.cinzelDecorative(
                      color: AppTheme.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _tutorialSteps
                            .asMap()
                            .entries
                            .map((entry) => _buildTutorialStep(
                                  entry.key + 1,
                                  entry.value,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: checkboxValue,
                            onChanged: (v) {
                              setSheetState(() => checkboxValue = v ?? true);
                              setState(() => _showTutorialAtStartup = v ?? true);
                            },
                            activeColor: AppTheme.gold,
                            checkColor: AppTheme.bloodRed,
                            side: const BorderSide(color: AppTheme.gold, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Show at startup',
                          style: TextStyle(
                            color: AppTheme.creamWhite,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (!checkboxValue) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You can toggle this again in Settings',
                                  style: TextStyle(color: AppTheme.creamWhite),
                                ),
                                backgroundColor: AppTheme.royalBlue,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                          Navigator.pushNamed(context, '/game', arguments: type);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.bloodRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'PLAY',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTutorialStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold, width: 1.5),
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.cinzel(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.creamWhite,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _tutorialSteps = [
    '10 rounds await — each with a monster that you must defeat.',
    'You must defeat all 10 monsters by doing your chosen workout properly.',
    'Each rep you perform deals damage to the monster.',
    'Do enough reps as needed, and keep a good pace to continuously deal damage and defeat the monster.',
    'The amount of reps needed increase the more you progress per round.',
    'Consistently deal damage! The monster attacks you if you fail to do at least 1 rep within 5 seconds of each other.',
    'You are given only 3 lives for failing to keep pace, and cannot be replenished once lost.',
    'The game ends when you defeat all 10 monsters or lose all 3 lives.',
    'Before and after every round, the player is given a brief 15 second cooldown period to recover.',
    'Attempting to pause or halt the game session will immediately trigger a game over. The entire game is a hands-free experience.',
    'The game session ends with victory when you slay all 10 monsters, or defeat if you lose all 3 lives.',
  ];

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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
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
                      onPressed: () => _onWorkoutSelected(context, WorkoutType.squats),
                    ),
                    const SizedBox(height: 16),
                    _WorkoutButton(
                      title: 'Jumping Jacks',
                      onPressed: () => _onWorkoutSelected(context, WorkoutType.jumpingJacks),
                    ),
                    const SizedBox(height: 16),
                    _WorkoutButton(
                      title: 'Side Crunches',
                      onPressed: () => _onWorkoutSelected(context, WorkoutType.obliqueCrunches),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const UserProfileFooter(),
        ],
      ),
    );
  }
}

class _WorkoutButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _WorkoutButton({
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.bloodRed,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
