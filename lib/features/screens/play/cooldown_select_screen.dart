import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums.dart';
import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';
import '../../../widgets/user_profile_footer.dart';
import '../../game/game_launch_args.dart';
import 'tutorial_popup.dart';

/// Final pre-game screen — cooldown duration slider.
///
/// Slider range: 2–30 seconds, default 15. Resets to default on every visit
/// (no persistence).
class CooldownSelectScreen extends StatefulWidget {
  const CooldownSelectScreen({super.key});

  @override
  State<CooldownSelectScreen> createState() => _CooldownSelectScreenState();
}

class _CooldownSelectScreenState extends State<CooldownSelectScreen> {
  static const int _minCooldown = 2;
  static const int _maxCooldown = 30;
  static const int _defaultCooldown = 15;

  int _cooldownSeconds = _defaultCooldown;

  WorkoutType _workoutType = WorkoutType.squats;
  bool _isMultiplayer = false;
  String? _player2UserId;
  String? _player2Email;
  bool _argsParsed = false;
  bool _bonusRounds = false;

  bool get _showBonusRoundsOption => !_isMultiplayer;

  void _parseArgs() {
    if (_argsParsed) return;
    _argsParsed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args['workoutType'] is WorkoutType) {
        _workoutType = args['workoutType'] as WorkoutType;
      }
      _isMultiplayer = args['isMultiplayer'] == true;
      _player2UserId = args['player2UserId'] as String?;
      _player2Email = args['player2Email'] as String?;
    }
  }

  void _handleBegin() {
    // Respect the user's "Show Tutorial at Startup" preference right before
    // the session begins. The popup itself reads the pref from Supabase and
    // will no-op (invoking onConfirm directly) if the toggle is off.
    showWorkoutTutorialIfNeeded(
      context,
      isMultiplayer: _isMultiplayer,
      onConfirm: _launchGame,
    );
  }

  void _launchGame() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/game',
      arguments: GameLaunchArgs(
        workoutType: _workoutType,
        cooldownSeconds: _cooldownSeconds,
        isMultiplayer: _isMultiplayer,
        player2UserId: _player2UserId,
        player2Email: _player2Email,
        bonusRoundsEnabled: _bonusRounds && !_isMultiplayer,
      ),
    );
  }

  String _workoutLabel(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:
        return 'Squats';
      case WorkoutType.jumpingJacks:
        return 'Jumping Jacks';
      case WorkoutType.obliqueCrunches:
        return 'Side Crunches';
    }
  }

  @override
  Widget build(BuildContext context) {
    _parseArgs();

    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      appBar: AppBar(
        backgroundColor: AppTheme.bloodRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'COOLDOWN',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _SummaryCard(
                      isMultiplayer: _isMultiplayer,
                      workoutLabel: _workoutLabel(_workoutType),
                      player2Email: _player2Email,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Set the rest period between rounds.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: AppTheme.creamWhite,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '$_cooldownSeconds s',
                        style: GoogleFonts.cinzelDecorative(
                          color: AppTheme.gold,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.gold,
                        inactiveTrackColor: AppTheme.gold.withValues(
                          alpha: 0.3,
                        ),
                        thumbColor: AppTheme.gold,
                        overlayColor: AppTheme.gold.withValues(alpha: 0.18),
                        valueIndicatorColor: AppTheme.gold,
                        valueIndicatorTextStyle: GoogleFonts.cinzel(
                          color: AppTheme.bloodRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Slider(
                        min: _minCooldown.toDouble(),
                        max: _maxCooldown.toDouble(),
                        divisions: _maxCooldown - _minCooldown,
                        value: _cooldownSeconds.toDouble(),
                        label: '$_cooldownSeconds s',
                        onChanged: (v) =>
                            setState(() => _cooldownSeconds = v.round()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_minCooldown}s',
                            style: GoogleFonts.cinzel(
                              color: AppTheme.creamWhite.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_maxCooldown}s',
                            style: GoogleFonts.cinzel(
                              color: AppTheme.creamWhite.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_showBonusRoundsOption) _buildBonusRoundsCard(),
                    const SizedBox(height: 36),
                    SizedBox(
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _handleBegin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.bloodRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'BEGIN',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusRoundsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.midnightNavy.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold, width: 1.5),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _bonusRounds,
            onChanged: (v) => setState(() => _bonusRounds = v ?? false),
            activeColor: AppTheme.gold,
            checkColor: AppTheme.bloodRed,
            side: const BorderSide(color: AppTheme.gold, width: 1.5),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BONUS ROUNDS',
                  style: GoogleFonts.cinzel(
                    color: AppTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Minigames after rounds 4 and 8',
                  style: GoogleFonts.cinzel(
                    color: AppTheme.creamWhite.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final bool isMultiplayer;
  final String workoutLabel;
  final String? player2Email;

  const _SummaryCard({
    required this.isMultiplayer,
    required this.workoutLabel,
    required this.player2Email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.midnightNavy.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMultiplayer ? Icons.group : Icons.person,
                color: AppTheme.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isMultiplayer ? 'MULTIPLAYER' : 'SINGLEPLAYER',
                style: GoogleFonts.cinzel(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            workoutLabel,
            style: GoogleFonts.cinzelDecorative(
              color: AppTheme.creamWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isMultiplayer && player2Email != null) ...[
            const SizedBox(height: 4),
            Text(
              'P2: $player2Email',
              style: GoogleFonts.cinzel(
                color: AppTheme.creamWhite.withValues(alpha: 0.75),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
