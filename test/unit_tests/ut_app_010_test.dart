import 'package:flutter_test/flutter_test.dart';

class _StatsHarness {
  static String formatTime(double totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  static String formatInterval(double seconds) {
    return '${seconds.toStringAsFixed(3)}s';
  }

  static Map<String, String> computeWorkoutStats(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return {
        'fastestClearTime': '--',
        'avgClearTime': '--',
        'bestRepInterval': '--',
        'avgRepInterval': '--',
        'roundsCompleted': '0',
        'repsFinished': '0',
        'victories': '0',
        'defeats': '0',
      };
    }

    final wonSessions = sessions.where((s) => s['won'] == true).toList();

    String fastestClearTime = '--';
    String avgClearTime = '--';
    if (wonSessions.isNotEmpty) {
      final times = wonSessions
          .map((s) => (s['total_time_seconds'] as num).toDouble())
          .toList();
      final minTime = times.reduce((a, b) => a < b ? a : b);
      fastestClearTime = formatTime(minTime);
      if (wonSessions.length >= 2) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        avgClearTime = formatTime(avgTime);
      }
    }

    final intervals = sessions
        .where((s) => s['best_rep_interval_seconds'] != null)
        .map((s) => (s['best_rep_interval_seconds'] as num).toDouble())
        .toList();
    String bestRepInterval = '--';
    if (intervals.isNotEmpty) {
      bestRepInterval = formatInterval(intervals.reduce((a, b) => a < b ? a : b));
    }

    final avgIntervals = sessions
        .where((s) => s['avg_rep_interval_seconds'] != null)
        .map((s) => (s['avg_rep_interval_seconds'] as num).toDouble())
        .toList();
    String avgRepInterval = '--';
    if (avgIntervals.length >= 2) {
      avgRepInterval =
          formatInterval(avgIntervals.reduce((a, b) => a + b) / avgIntervals.length);
    }

    final totalRounds = sessions.fold<int>(
      0,
      (sum, s) => sum + ((s['rounds_completed'] as int?) ?? 0),
    );
    final totalReps = sessions.fold<int>(
      0,
      (sum, s) => sum + ((s['total_reps'] as int?) ?? 0),
    );

    return {
      'fastestClearTime': fastestClearTime,
      'avgClearTime': avgClearTime,
      'bestRepInterval': bestRepInterval,
      'avgRepInterval': avgRepInterval,
      'roundsCompleted': totalRounds.toString(),
      'repsFinished': totalReps.toString(),
      'victories': wonSessions.length.toString(),
      'defeats': sessions.where((s) => s['won'] == false).length.toString(),
    };
  }
}

void main() {
  test('UT-APP-010 computes workout stats from session data', () {
    final stats = _StatsHarness.computeWorkoutStats([
      {
        'won': true,
        'total_time_seconds': 75.5,
        'best_rep_interval_seconds': 1.7,
        'avg_rep_interval_seconds': 2.2,
        'rounds_completed': 10,
        'total_reps': 65,
      },
      {
        'won': true,
        'total_time_seconds': 80.0,
        'best_rep_interval_seconds': 1.9,
        'avg_rep_interval_seconds': 2.4,
        'rounds_completed': 10,
        'total_reps': 66,
      },
      {
        'won': false,
        'total_time_seconds': 50.0,
        'best_rep_interval_seconds': 2.1,
        'avg_rep_interval_seconds': 2.8,
        'rounds_completed': 6,
        'total_reps': 39,
      },
    ]);

    expect(stats['fastestClearTime'], '01:15.50');
    expect(stats['avgClearTime'], '01:17.75');
    expect(stats['bestRepInterval'], '1.700s');
    expect(stats['avgRepInterval'], '2.467s');
    expect(stats['roundsCompleted'], '26');
    expect(stats['repsFinished'], '170');
    expect(stats['victories'], '2');
    expect(stats['defeats'], '1');
  });
}
