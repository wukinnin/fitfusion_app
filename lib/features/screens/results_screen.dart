import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../widgets/user_profile_footer.dart';
import '../game/game_session.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<Offset> _heartsSlideAnimation;
  GameSession? _session;
  bool _audioPlayed = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _heartsSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));
    _slideController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is GameSession) {
        _session = args;
        _playResultAudio();
      }
    }
  }

  void _playResultAudio() {
    if (_audioPlayed || _session == null) return;
    _audioPlayed = true;
    try {
      if (_session!.won) {
        FlameAudio.play('sfx/victory_orchestra.mp3');
      } else {
        FlameAudio.play('sfx/lose_violin.mp3');
      }
    } catch (e) {
      debugPrint('[ResultsScreen] Audio error: $e');
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  String _formatTime(double totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  void _onRetry() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bloodRed,
        title: const Text('Retry?',
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to retry?',
            style: TextStyle(color: AppTheme.creamWhite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.creamWhite)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/game',
                (route) => route.isFirst,
                arguments: _session!.workoutType,
              );
            },
            child: const Text('Retry', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );
  }

  void _onQuit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bloodRed,
        title: const Text('Quit?',
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to quit?',
            style: TextStyle(color: AppTheme.creamWhite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.creamWhite)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            child: const Text('Quit', style: TextStyle(color: AppTheme.crimson)),
          ),
        ],
      ),
    );
  }

  String _workoutLabel(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:
        return 'SQUATS';
      case WorkoutType.jumpingJacks:
        return 'JUMPING JACKS';
      case WorkoutType.obliqueCrunches:
        return 'SIDE CRUNCHES';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bloodRed,
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    final isVictory = session.won;
    final tintColor = isVictory
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.25);
    final headerColor = isVictory ? AppTheme.emerald : AppTheme.crimson;
    final headerText = isVictory ? 'VICTORY' : 'DEFEAT';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.bloodRed,
        body: Stack(
          children: [
            Container(color: tintColor),
            SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        headerText,
                        style: TextStyle(
                          color: headerColor,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatRow('Clear Time:', _formatTime(session.totalTimeSeconds)),
                            const SizedBox(height: 8),
                            _buildStatRow('Rounds Complete:', '${session.roundsCompleted} / $kTotalRounds'),
                            const SizedBox(height: 8),
                            _buildStatRow('Reps Finished:', '${session.totalReps} / ${session.totalRepsRequired}'),
                            const SizedBox(height: 8),
                            _buildStatRow('Best Rep Interval:', session.bestRepIntervalSeconds > 0 ? '${session.bestRepIntervalSeconds.toStringAsFixed(2)}s' : '--'),
                            const SizedBox(height: 8),
                            _buildStatRow('Avg Rep Interval:', session.avgRepIntervalSeconds > 0 ? '${session.avgRepIntervalSeconds.toStringAsFixed(2)}s' : '--'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isVictory)
                        Text(
                          'You have defeated all $kTotalRounds monsters!',
                          style: const TextStyle(
                            color: AppTheme.creamWhite,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const Spacer(),
                      SizedBox(
                        width: 200,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.bloodRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('RETRY',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onQuit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.bloodRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('QUIT',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SlideTransition(
                        position: _heartsSlideAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(kStartingLives, (i) {
                            final alive = i < (kStartingLives - session.livesLost);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.favorite,
                                color: alive ? const Color(0xFF1A3A8A) : AppTheme.crimson,
                                size: 28,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _workoutLabel(session.workoutType),
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: UserProfileFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.creamWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.creamWhite,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
