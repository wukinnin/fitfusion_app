import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';

/// Shared "HOW TO PLAY" bottom-sheet used by both the singleplayer and
/// multiplayer workout-select screens. When the user confirms, [onConfirm]
/// is invoked (typically navigating onward to the cooldown picker).
///
/// Honours the per-user `show_tutorial` flag stored on the Supabase users
/// row. If disabled, [onConfirm] is invoked immediately without showing
/// the sheet.
Future<void> showWorkoutTutorialIfNeeded(
  BuildContext context, {
  required VoidCallback onConfirm,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  bool show = true;
  if (user != null) {
    try {
      final row = await client
          .from('users')
          .select('show_tutorial')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        show = (row['show_tutorial'] as bool?) ?? true;
      }
    } catch (_) {
      // Best-effort: default to showing the tutorial on any read failure.
    }
  }

  if (!show) {
    onConfirm();
    return;
  }

  if (!context.mounted) return;
  await _showTutorialBottomSheet(context, onConfirm);
}

Future<void> _updateShowTutorial(bool value) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;
  try {
    await client
        .from('users')
        .update({'show_tutorial': value})
        .eq('id', user.id);
  } catch (e) {
    debugPrint('[TutorialPopup] Failed to update show_tutorial: $e');
  }
}

Future<void> _showTutorialBottomSheet(
  BuildContext context,
  VoidCallback onConfirm,
) {
  bool checkboxValue = true;
  return showModalBottomSheet(
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
                          .map(
                            (entry) =>
                                _buildTutorialStep(entry.key + 1, entry.value),
                          )
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
                            final newVal = v ?? true;
                            setSheetState(() => checkboxValue = newVal);
                            _updateShowTutorial(newVal);
                          },
                          activeColor: AppTheme.gold,
                          checkColor: AppTheme.bloodRed,
                          side: const BorderSide(
                            color: AppTheme.gold,
                            width: 2,
                          ),
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
                              backgroundColor: AppTheme.bloodRed,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.bloodRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 22,
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

const List<String> _tutorialSteps = [
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
