import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/fitfusion_animated_background.dart';
import '../../widgets/user_profile_footer.dart';

class _GroupedWorkoutRows {
  final List<Map<String, dynamic>> singleplayer;
  final List<Map<String, dynamic>> multiplayer;

  const _GroupedWorkoutRows({
    required this.singleplayer,
    required this.multiplayer,
  });
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static final _client = Supabase.instance.client;

  // Per-workout metric index: 0 = Clear Time, 1 = Best Rep Interval
  final Map<int, int> _workoutMetricIndex = {0: 0, 1: 0, 2: 0};
  // Lifetime metric index: 0 = Total Reps, 1 = Total Victories
  int _lifetimeMetricIndex = 0;
  // Session-mode index for the per-workout tabs only:
  //   0 = Singleplayer (default), 1 = Multiplayer.
  // The Lifetime tab ignores this — totals are user-scoped regardless of mode.
  int _modeIndex = 0;

  static const _workoutTabs = ['Squats', 'Jacks', 'Crunches', 'Lifetime'];
  static const _workoutMetrics = ['Clear Time', 'Best Rep Interval'];
  static const _lifetimeMetrics = ['Total Reps', 'Total Victories'];
  static const _modes = ['Singleplayer', 'Multiplayer'];
  static const _workoutDbKeys = ['squats', 'jumping_jacks', 'side_crunches'];

  bool _loading = true;

  // Cached leaderboard data, keyed by `'$tab:$metric:$mode'`.
  //   - Singleplayer rows: {rank, username, value}
  //   - Multiplayer rows: {rank, username_a, username_b, value}
  // Workout tabs: 3 tabs × 2 metrics × 2 modes
  // Lifetime tab: 1 tab × 2 metrics (mode dimension always 0)
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Rebuild on tab change so the SP/MP toggle hides on the Lifetime tab.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _cacheKey(int tab, int metric, [int mode = 0]) => '$tab:$metric:$mode';

  Future<void> _fetchAll() async {
    try {
      final sessionRows = await _client
          .from('sessions')
          .select(
            'id, user_id, workout_type, won, rounds_completed, total_reps, '
            'lives_lost, total_time_seconds, best_rep_interval_seconds, '
            'avg_rep_interval_seconds, completed_at, users(username)',
          )
          .eq('won', true)
          .not('total_time_seconds', 'is', null)
          .order('completed_at', ascending: false)
          .limit(500);

      final workoutRows = (sessionRows as List)
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
          .toList();
      final grouped = _groupWorkoutSessions(workoutRows);

      for (int tab = 0; tab < 3; tab++) {
        final dbKey = _workoutDbKeys[tab];

        _cache[_cacheKey(tab, 0, 0)] = _rankRows(
          grouped.singleplayer
              .where((r) => r['workout_type'] == dbKey)
              .toList(),
          metricKey: 'total_time_seconds',
        );
        _cache[_cacheKey(tab, 1, 0)] = _rankRows(
          grouped.singleplayer
              .where((r) => r['workout_type'] == dbKey)
              .toList(),
          metricKey: 'best_rep_interval_seconds',
        );
        _cache[_cacheKey(tab, 0, 1)] = _rankRows(
          grouped.multiplayer.where((r) => r['workout_type'] == dbKey).toList(),
          metricKey: 'total_time_seconds',
        );
        _cache[_cacheKey(tab, 1, 1)] = _rankRows(
          grouped.multiplayer.where((r) => r['workout_type'] == dbKey).toList(),
          metricKey: 'best_rep_interval_seconds',
        );
      }

      // Fetch lifetime leaderboards
      final repsRows = await _client.from('v_top10_lifetime_reps').select();
      _cache[_cacheKey(3, 0, 0)] = List<Map<String, dynamic>>.from(
        (repsRows as List)
          ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)),
      );

      final victoriesRows = await _client
          .from('v_top10_lifetime_victories')
          .select();
      _cache[_cacheKey(3, 1, 0)] = List<Map<String, dynamic>>.from(
        (victoriesRows as List)
          ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)),
      );
    } catch (e) {
      assert(() {
        debugPrint('[LeaderboardScreen] Failed to fetch leaderboards: $e');
        return true;
      }());
    }

    if (mounted) setState(() => _loading = false);
  }

  _GroupedWorkoutRows _groupWorkoutSessions(List<Map<String, dynamic>> rows) {
    final buckets = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      buckets.putIfAbsent(_multiplayerPairKey(row), () => []).add(row);
    }

    final pairedIds = <String>{};
    final multiplayerRows = <Map<String, dynamic>>[];

    for (final bucket in buckets.values) {
      final byUser = <String, Map<String, dynamic>>{};
      for (final row in bucket) {
        final userId = row['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        byUser.putIfAbsent(userId, () => row);
      }

      if (byUser.length < 2) continue;

      final pair = byUser.values.take(2).toList();
      pairedIds.add(pair[0]['id'].toString());
      pairedIds.add(pair[1]['id'].toString());
      multiplayerRows.add(_buildMultiplayerRow(pair[0], pair[1]));
    }

    final singleplayerRows = rows
        .where((row) => !pairedIds.contains(row['id']?.toString()))
        .map(_buildSingleplayerRow)
        .toList();

    return _GroupedWorkoutRows(
      singleplayer: singleplayerRows,
      multiplayer: multiplayerRows,
    );
  }

  String _multiplayerPairKey(Map<String, dynamic> row) {
    return [
      row['workout_type'],
      row['won'],
      row['rounds_completed'],
      row['total_reps'],
      row['lives_lost'],
      _metricKeyValue(row['total_time_seconds']),
      _metricKeyValue(row['best_rep_interval_seconds']),
      _metricKeyValue(row['avg_rep_interval_seconds']),
      row['completed_at'],
    ].join('|');
  }

  String _metricKeyValue(dynamic value) {
    final number = _asDouble(value);
    if (number == null) return '';
    return number.toStringAsFixed(6);
  }

  Map<String, dynamic> _buildSingleplayerRow(Map<String, dynamic> row) {
    return {
      'workout_type': row['workout_type'],
      'username': _usernameForRow(row),
      'total_time_seconds': row['total_time_seconds'],
      'best_rep_interval_seconds': row['best_rep_interval_seconds'],
    };
  }

  Map<String, dynamic> _buildMultiplayerRow(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    return {
      'workout_type': first['workout_type'],
      'username_a': _usernameForRow(first),
      'username_b': _usernameForRow(second),
      'total_time_seconds': first['total_time_seconds'],
      'best_rep_interval_seconds': first['best_rep_interval_seconds'],
    };
  }

  String _usernameForRow(Map<String, dynamic> row) {
    final user = row['users'];
    if (user is Map && user['username'] != null) {
      return user['username'].toString();
    }
    return '--';
  }

  List<Map<String, dynamic>> _rankRows(
    List<Map<String, dynamic>> rows, {
    required String metricKey,
  }) {
    final ranked =
        rows.where((row) => _asDouble(row[metricKey]) != null).map((row) {
          return {...row, 'value': _asDouble(row[metricKey])};
        }).toList()..sort((a, b) {
          return (_asDouble(a['value']) ?? double.infinity).compareTo(
            _asDouble(b['value']) ?? double.infinity,
          );
        });

    return List<Map<String, dynamic>>.generate(
      ranked.length > 10 ? 10 : ranked.length,
      (index) => {...ranked[index], 'rank': index + 1},
    );
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatValue(dynamic value, {required bool isTime}) {
    if (value == null) return '--';
    final num n = value is num ? value : num.tryParse(value.toString()) ?? 0;
    if (isTime) {
      final totalSeconds = n.toDouble();
      final minutes = totalSeconds ~/ 60;
      final secs = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
    }
    if (n is int || n == n.roundToDouble()) {
      return n.toInt().toString();
    }
    return '${n.toDouble().toStringAsFixed(3)}s';
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
          'LEADERBOARDS',
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
          labelStyle: GoogleFonts.cinzel(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 12),
          tabs: _workoutTabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: FitFusionAnimatedBackground(
        child: Column(
          children: [
            const UserProfileFooter(),
            // Session-mode toggle (SP / MP). Hidden on the Lifetime tab —
            // lifetime totals are user-scoped and don't differ by mode.
            if (_tabController.index != 3) ...[
              const SizedBox(height: 12),
              _buildModeSelector(),
            ],
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildWorkoutTab(0),
                        _buildWorkoutTab(1),
                        _buildWorkoutTab(2),
                        _buildLifetimeTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutTab(int tabIndex) {
    final selectedMetric = _workoutMetricIndex[tabIndex] ?? 0;
    final entries =
        _cache[_cacheKey(tabIndex, selectedMetric, _modeIndex)] ?? [];
    // Clear time and rep interval are both "lower is better" formatted as time/seconds
    final isTime = selectedMetric == 0;
    final isMultiplayer = _modeIndex == 1;
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildMetricSelector(
          metrics: _workoutMetrics,
          selected: selectedMetric,
          onChanged: (i) => setState(() => _workoutMetricIndex[tabIndex] = i),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildLeaderboardTable(
            entries: entries,
            isTime: isTime,
            isMultiplayer: isMultiplayer,
          ),
        ),
      ],
    );
  }

  Widget _buildLifetimeTab() {
    final entries = _cache[_cacheKey(3, _lifetimeMetricIndex, 0)] ?? [];
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildMetricSelector(
          metrics: _lifetimeMetrics,
          selected: _lifetimeMetricIndex,
          onChanged: (i) => setState(() => _lifetimeMetricIndex = i),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildLeaderboardTable(
            entries: entries,
            isTime: false,
            isMultiplayer: false,
          ),
        ),
      ],
    );
  }

  /// Singleplayer / Multiplayer pill switcher. Slightly larger and bolder
  /// than the per-tab metric selector so it reads as a higher-tier filter.
  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_modes.length, (i) {
          final isSelected = i == _modeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _modeIndex = i),
              child: Container(
                margin: EdgeInsets.only(
                  left: i == 0 ? 0 : 6,
                  right: i == _modes.length - 1 ? 0 : 6,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.gold.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.gold
                        : AppTheme.gold.withValues(alpha: 0.35),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      i == 0 ? Icons.person : Icons.group,
                      size: 16,
                      color: isSelected
                          ? AppTheme.gold
                          : AppTheme.creamWhite.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _modes[i].toUpperCase(),
                      style: GoogleFonts.cinzel(
                        color: isSelected
                            ? AppTheme.gold
                            : AppTheme.creamWhite.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricSelector({
    required List<String> metrics,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(metrics.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.gold.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.gold
                        : AppTheme.gold.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  metrics[i].toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: isSelected
                        ? AppTheme.gold
                        : AppTheme.creamWhite.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeaderboardTable({
    required List<Map<String, dynamic>> entries,
    required bool isTime,
    required bool isMultiplayer,
  }) {
    final itemCount = entries.isEmpty ? 10 : entries.length;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        final hasData = i < entries.length;
        final rank = hasData ? entries[i]['rank'] : i + 1;
        final value = hasData
            ? _formatValue(entries[i]['value'], isTime: isTime)
            : '--';

        // Username display:
        //   - Singleplayer: just `username`
        //   - Multiplayer:  `[A] and [B]` — both required, fallback '--' each.
        final String displayName;
        if (isMultiplayer) {
          final a = hasData
              ? (entries[i]['username_a'] ?? entries[i]['username'] ?? '--')
              : '--';
          final b = hasData ? (entries[i]['username_b'] ?? '--') : '--';
          displayName = '[$a] and [$b]';
        } else {
          displayName = hasData ? (entries[i]['username'] ?? '--') : '--';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: i == 0
                ? AppTheme.gold.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: i == 0
                  ? AppTheme.gold.withValues(alpha: 0.5)
                  : AppTheme.gold.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#$rank',
                  style: GoogleFonts.cinzel(
                    color: i < 3 ? AppTheme.gold : AppTheme.creamWhite,
                    fontSize: 14,
                    fontWeight: i < 3 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: hasData
                        ? AppTheme.creamWhite
                        : AppTheme.creamWhite.withValues(alpha: 0.4),
                    fontSize: isMultiplayer ? 13 : 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: hasData
                      ? AppTheme.gold
                      : AppTheme.creamWhite.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
