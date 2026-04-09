import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/enums.dart';
import '../../core/extensions.dart';
import '../../core/theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static final _client = Supabase.instance.client;

  static const _tabs = ['Squats', 'Jacks', 'Crunches', 'Overall'];
  static const _workoutTypes = [
    WorkoutType.squats,
    WorkoutType.jumpingJacks,
    WorkoutType.obliqueCrunches,
  ];

  bool _loading = true;

  // Per-workout stats (indexed 0=squats, 1=jacks, 2=crunches)
  final List<Map<String, String>> _workoutStats = List.generate(3, (_) => {});
  // Overall lifetime stats
  Map<String, String> _overallStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(double totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  String _formatInterval(double seconds) {
    return '${seconds.toStringAsFixed(3)}s';
  }

  Future<void> _fetchStats() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // Fetch all user sessions
      final sessions = await _client
          .from('sessions')
          .select()
          .eq('user_id', user.id);

      // Build per-workout stats
      for (int i = 0; i < _workoutTypes.length; i++) {
        final dbKey = _workoutTypes[i].dbKey;
        final wSessions = (sessions as List)
            .where((s) => s['workout_type'] == dbKey)
            .toList();

        if (wSessions.isEmpty) {
          _workoutStats[i] = {
            'fastestClearTime': '--',
            'avgClearTime': '--',
            'bestRepInterval': '--',
            'avgRepInterval': '--',
            'roundsCompleted': '0',
            'repsFinished': '0',
            'victories': '0',
            'defeats': '0',
          };
          continue;
        }

        // Session stats (from winning sessions only for clear time)
        final wonSessions = wSessions.where((s) => s['won'] == true).toList();

        String fastestClearTime = '--';
        String avgClearTime = '--';
        if (wonSessions.isNotEmpty) {
          final times = wonSessions
              .map((s) => (s['total_time_seconds'] as num).toDouble())
              .toList();
          final minTime = times.reduce((a, b) => a < b ? a : b);
          fastestClearTime = _formatTime(minTime);
          if (wonSessions.length >= 2) {
            final avgTime = times.reduce((a, b) => a + b) / times.length;
            avgClearTime = _formatTime(avgTime);
          }
        }

        // Best rep interval (across all sessions)
        final intervals = wSessions
            .where((s) => s['best_rep_interval_seconds'] != null)
            .map((s) => (s['best_rep_interval_seconds'] as num).toDouble())
            .toList();
        String bestRepInterval = '--';
        if (intervals.isNotEmpty) {
          bestRepInterval = _formatInterval(
              intervals.reduce((a, b) => a < b ? a : b));
        }

        // Avg rep interval (across all sessions)
        final avgIntervals = wSessions
            .where((s) => s['avg_rep_interval_seconds'] != null)
            .map((s) => (s['avg_rep_interval_seconds'] as num).toDouble())
            .toList();
        String avgRepInterval = '--';
        if (avgIntervals.length >= 2) {
          avgRepInterval = _formatInterval(
              avgIntervals.reduce((a, b) => a + b) / avgIntervals.length);
        }

        // Lifetime stats per workout
        final totalRounds = wSessions.fold<int>(
            0, (sum, s) => sum + ((s['rounds_completed'] as int?) ?? 0));
        final totalReps = wSessions.fold<int>(
            0, (sum, s) => sum + ((s['total_reps'] as int?) ?? 0));
        final victories = wonSessions.length;
        final defeats = wSessions.where((s) => s['won'] == false).length;

        _workoutStats[i] = {
          'fastestClearTime': fastestClearTime,
          'avgClearTime': avgClearTime,
          'bestRepInterval': bestRepInterval,
          'avgRepInterval': avgRepInterval,
          'roundsCompleted': totalRounds.toString(),
          'repsFinished': totalReps.toString(),
          'victories': victories.toString(),
          'defeats': defeats.toString(),
        };
      }

      // Overall lifetime stats from view
      final lifetime = await _client
          .from('v_user_lifetime_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (lifetime != null) {
        _overallStats = {
          'totalSessions': (lifetime['total_sessions'] ?? 0).toString(),
          'totalReps': (lifetime['total_reps'] ?? 0).toString(),
          'totalRounds': (lifetime['total_rounds'] ?? 0).toString(),
          'totalVictories': (lifetime['total_victories'] ?? 0).toString(),
        };
      } else {
        _overallStats = {
          'totalSessions': '0',
          'totalReps': '0',
          'totalRounds': '0',
          'totalVictories': '0',
        };
      }
    } catch (e) {
      assert(() {
        debugPrint('[StatsScreen] Failed to fetch stats: $e');
        return true;
      }());
    }

    if (mounted) setState(() => _loading = false);
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
          'STATS',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: AppTheme.gold,
          indicatorWeight: 3,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.creamWhite.withValues(alpha: 0.5),
          labelStyle: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 12),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWorkoutStatsTab(0),
                _buildWorkoutStatsTab(1),
                _buildWorkoutStatsTab(2),
                _buildOverallTab(),
              ],
            ),
    );
  }

  Widget _buildWorkoutStatsTab(int index) {
    final s = _workoutStats[index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('SESSION STATS'),
          const SizedBox(height: 8),
          _buildStatCard('Fastest Clear Time', s['fastestClearTime'] ?? '--'),
          _buildStatCard('Average Clear Time', s['avgClearTime'] ?? '--'),
          _buildStatCard('Best Rep Interval', s['bestRepInterval'] ?? '--'),
          _buildStatCard('Average Rep Interval', s['avgRepInterval'] ?? '--'),
          const SizedBox(height: 24),
          _buildSectionHeader('LIFETIME STATS'),
          const SizedBox(height: 8),
          _buildStatCard('Rounds Completed', s['roundsCompleted'] ?? '0'),
          _buildStatCard('Reps Finished', s['repsFinished'] ?? '0'),
          _buildStatCard('Victories', s['victories'] ?? '0'),
          _buildStatCard('Defeats', s['defeats'] ?? '0'),
        ],
      ),
    );
  }

  Widget _buildOverallTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('LIFETIME TOTALS'),
          const SizedBox(height: 8),
          _buildStatCard('Total Sessions', _overallStats['totalSessions'] ?? '0'),
          _buildStatCard('Total Reps', _overallStats['totalReps'] ?? '0'),
          _buildStatCard('Total Rounds', _overallStats['totalRounds'] ?? '0'),
          _buildStatCard('Total Victories', _overallStats['totalVictories'] ?? '0'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.cinzel(
          color: AppTheme.gold,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.creamWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: value == '--'
                  ? AppTheme.creamWhite.withValues(alpha: 0.4)
                  : AppTheme.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
