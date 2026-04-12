import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LeaderboardService {
  Future<Map<String, List<Map<String, dynamic>>>> fetchLeaderboards();
}

class SupabaseLeaderboardService implements LeaderboardService {
  SupabaseLeaderboardService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _workoutDbKeys = ['squats', 'jumping_jacks', 'side_crunches'];

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchLeaderboards() async {
    final cache = <String, List<Map<String, dynamic>>>{};
    final clearTimeRows = await _client.from('v_top10_clear_time').select();
    final repIntervalRows = await _client.from('v_top10_best_rep_interval').select();

    for (int tab = 0; tab < 3; tab++) {
      final dbKey = _workoutDbKeys[tab];

      final clearTimeEntries = (clearTimeRows as List)
          .where((r) => r['workout_type'] == dbKey)
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
          .toList()
        ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
      cache['$tab:0'] = clearTimeEntries;

      final repIntervalEntries = (repIntervalRows as List)
          .where((r) => r['workout_type'] == dbKey)
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
          .toList()
        ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
      cache['$tab:1'] = repIntervalEntries;
    }

    final repsRows = await _client.from('v_top10_lifetime_reps').select();
    cache['3:0'] = List<Map<String, dynamic>>.from(
      (repsRows as List)..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)),
    );

    final victoriesRows = await _client.from('v_top10_lifetime_victories').select();
    cache['3:1'] = List<Map<String, dynamic>>.from(
      (victoriesRows as List)
        ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)),
    );

    return cache;
  }
}
