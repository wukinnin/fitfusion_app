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
  bool isMultiplayer = false,
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
  await _showTutorialBottomSheet(
    context,
    isMultiplayer: isMultiplayer,
    onConfirm: onConfirm,
  );
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
  BuildContext context, {
  required bool isMultiplayer,
  required VoidCallback onConfirm,
}) {
  bool checkboxValue = true;
  final tutorialSections = isMultiplayer
      ? _multiplayerTutorialSections
      : _singleplayerTutorialSections;
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
                      children: tutorialSections
                          .map((section) => _buildTutorialSection(section))
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

Widget _buildTutorialSection(_TutorialSection section) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: GoogleFonts.cinzel(
            color: AppTheme.gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...section.steps.map(_buildTutorialStep),
      ],
    ),
  );
}

Widget _buildTutorialStep(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppTheme.gold,
            shape: BoxShape.circle,
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

class _TutorialSection {
  const _TutorialSection({required this.title, required this.steps});

  final String title;
  final List<String> steps;
}

const List<_TutorialSection> _singleplayerTutorialSections = [
  _TutorialSection(
    title: 'MAIN GAME',
    steps: [
      'A scary dragon awaits. You must slay it.',
      'You are going to have to slay the beast by way of working out!',
      'Each rep you perform deals damage to the monster.',
      '10 grueling rounds lie ahead to test your stamina, and finally slay the dragon.',
      "Try not to get slain yourself! Don't fall behind the pace.",
      "You only get 3 lives to pace yourself, if you fail, it's game over!",
    ],
  ),
  _TutorialSection(
    title: 'BONUS ROUND',
    steps: [
      'Use your right hand to collect as many diamonds possible before time expires.',
      'The gems collected will cut your clear time by 1 second.',
      'If you touch the poison, the bonus round is over.',
      "Don't worry! Your session will still continue regardless.",
    ],
  ),
];

const List<_TutorialSection> _multiplayerTutorialSections = [
  _TutorialSection(
    title: 'MAIN GAME',
    steps: [
      'A scary dragon awaits. You must slay it.',
      'You are going to have to slay the beast by way of working out!',
      'But not without the power of friendship! You must work out together!',
      'You perform each rep together as one to deal damage to the monster.',
      '10 grueling rounds lie ahead to test your stamina, to finally slay the dragon.',
      "Try not to get slain yourselves! Don't fall behind the pace, and don't leave each other behind.",
      "You both only share 3 lives to pace yourself, if you fail, it's game over!",
    ],
  ),
];
