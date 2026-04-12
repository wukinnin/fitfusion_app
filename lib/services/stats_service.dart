import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/enums.dart';
import '../core/extensions.dart';

class StatsData {
  final List<Map<String, String>> workoutStats;
  final Map<String, String> overallStats;

  const StatsData({
    required this.workoutStats,
    required this.overallStats,
  });
}

abstract class StatsService {
  Future<StatsData> fetchStats();
}

class SupabaseStatsService implements StatsService {
  SupabaseStatsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _workoutTypes = [
    WorkoutType.squats,
    WorkoutType.jumpingJacks,
    WorkoutType.obliqueCrunches,
  ];

  @override
  Future<StatsData> fetchStats() async {
    final user = _client.auth.currentUser;
    final workoutStats = List<Map<String, String>>.generate(3, (_) => {});

    if (user == null) {
      return const StatsData(
        workoutStats: [
          {
            'fastestClearTime': '--',
            'avgClearTime': '--',
            'bestRepInterval': '--',
            'avgRepInterval': '--',
            'roundsCompleted': '0',
            'repsFinished': '0',
            'victories': '0',
            'defeats': '0',
          },
          {
            'fastestClearTime': '--',
            'avgClearTime': '--',
            'bestRepInterval': '--',
            'avgRepInterval': '--',
            'roundsCompleted': '0',
            'repsFinished': '0',
            'victories': '0',
            'defeats': '0',
          },
          {
            'fastestClearTime': '--',
            'avgClearTime': '--',
            'bestRepInterval': '--',
            'avgRepInterval': '--',
            'roundsCompleted': '0',
            'repsFinished': '0',
            'victories': '0',
            'defeats': '0',
          },
        ],
        overallStats: {
          'totalSessions': '0',
          'totalReps': '0',
          'totalRounds': '0',
          'totalVictories': '0',
        },
      );
    }

    final sessions = await _client.from('sessions').select().eq('user_id', user.id);

    for (int i = 0; i < _workoutTypes.length; i++) {
      final dbKey = _workoutTypes[i].dbKey;
      final wSessions = (sessions as List).where((s) => s['workout_type'] == dbKey).toList();

      if (wSessions.isEmpty) {
        workoutStats[i] = _emptyWorkoutStats();
        continue;
      }

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

      final intervals = wSessions
          .where((s) => s['best_rep_interval_seconds'] != null)
          .map((s) => (s['best_rep_interval_seconds'] as num).toDouble())
          .toList();
      String bestRepInterval = '--';
      if (intervals.isNotEmpty) {
        bestRepInterval =
            _formatInterval(intervals.reduce((a, b) => a < b ? a : b));
      }

      final avgIntervals = wSessions
          .where((s) => s['avg_rep_interval_seconds'] != null)
          .map((s) => (s['avg_rep_interval_seconds'] as num).toDouble())
          .toList();
      String avgRepInterval = '--';
      if (avgIntervals.length >= 2) {
        avgRepInterval =
            _formatInterval(avgIntervals.reduce((a, b) => a + b) / avgIntervals.length);
      }

      final totalRounds = wSessions.fold<int>(
        0,
        (sum, s) => sum + ((s['rounds_completed'] as int?) ?? 0),
      );
      final totalReps = wSessions.fold<int>(
        0,
        (sum, s) => sum + ((s['total_reps'] as int?) ?? 0),
      );

      workoutStats[i] = {
        'fastestClearTime': fastestClearTime,
        'avgClearTime': avgClearTime,
        'bestRepInterval': bestRepInterval,
        'avgRepInterval': avgRepInterval,
        'roundsCompleted': totalRounds.toString(),
        'repsFinished': totalReps.toString(),
        'victories': wonSessions.length.toString(),
        'defeats': wSessions.where((s) => s['won'] == false).length.toString(),
      };
    }

    final lifetime = await _client
        .from('v_user_lifetime_stats')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return StatsData(
      workoutStats: workoutStats,
      overallStats: lifetime != null
          ? {
              'totalSessions': (lifetime['total_sessions'] ?? 0).toString(),
              'totalReps': (lifetime['total_reps'] ?? 0).toString(),
              'totalRounds': (lifetime['total_rounds'] ?? 0).toString(),
              'totalVictories': (lifetime['total_victories'] ?? 0).toString(),
            }
          : {
              'totalSessions': '0',
              'totalReps': '0',
              'totalRounds': '0',
              'totalVictories': '0',
            },
    );
  }

  Map<String, String> _emptyWorkoutStats() => {
        'fastestClearTime': '--',
        'avgClearTime': '--',
        'bestRepInterval': '--',
        'avgRepInterval': '--',
        'roundsCompleted': '0',
        'repsFinished': '0',
        'victories': '0',
        'defeats': '0',
      };

  String _formatTime(double totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  String _formatInterval(double seconds) => '${seconds.toStringAsFixed(3)}s';
}
