import 'package:flutter_test/flutter_test.dart';

class _LeaderboardHarness {
  static List<Map<String, dynamic>> sortedEntries(
    List<Map<String, dynamic>> rows,
    String workoutType,
  ) {
    return rows
        .where((row) => row['workout_type'] == workoutType)
        .map((row) => Map<String, dynamic>.from(row))
        .toList()
      ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
  }

  static String formatValue(dynamic value, {required bool isTime}) {
    if (value == null) return '--';
    final num number =
        value is num ? value : num.tryParse(value.toString()) ?? 0;
    if (isTime) {
      final totalSeconds = number.toDouble();
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(2).padLeft(5, '0')}';
    }
    if (number is int || number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return '${number.toDouble().toStringAsFixed(3)}s';
  }
}

void main() {
  test('UT-APP-008 sorts leaderboard rows by rank for the selected workout',
      () {
    final rows = [
      {'workout_type': 'squats', 'rank': 2, 'username': 'Beta', 'value': 75.4},
      {'workout_type': 'jumping_jacks', 'rank': 1, 'username': 'Gamma', 'value': 1.9},
      {'workout_type': 'squats', 'rank': 1, 'username': 'Alpha', 'value': 72.2},
    ];

    final sorted = _LeaderboardHarness.sortedEntries(rows, 'squats');

    expect(sorted.map((row) => row['username']), ['Alpha', 'Beta']);
  });

  test('UT-APP-008 formats clear time and rep interval values correctly', () {
    expect(
      _LeaderboardHarness.formatValue(72.2, isTime: true),
      '01:12.20',
    );
    expect(
      _LeaderboardHarness.formatValue(1.8765, isTime: false),
      '1.877s',
    );
    expect(
      _LeaderboardHarness.formatValue(12, isTime: false),
      '12',
    );
  });
}
