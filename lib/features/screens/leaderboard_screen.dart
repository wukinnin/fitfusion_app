import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/fitfusion_animated_background.dart';
import '../../widgets/user_profile_footer.dart';

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

  static const _workoutTabs = ['Squats', 'Jacks', 'Crunches', 'Lifetime'];
  static const _workoutMetrics = ['Clear Time', 'Best Rep Interval'];
  static const _lifetimeMetrics = ['Total Reps', 'Total Victories'];
  static const _workoutDbKeys = ['squats', 'jumping_jacks', 'side_crunches'];

  bool _loading = true;

  // Cached leaderboard data: [tabIndex][metricIndex] → list of {rank, username, value}
  // Workout tabs: 3 tabs × 2 metrics each
  // Lifetime tab: 1 tab × 2 metrics
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _cacheKey(int tab, int metric) => '$tab:$metric';

  Future<void> _fetchAll() async {
    try {
      // Fetch workout leaderboards (clear time + best rep interval per workout type)
      final clearTimeRows = await _client.from('v_top10_clear_time').select();
      final repIntervalRows = await _client
          .from('v_top10_best_rep_interval')
          .select();

      for (int tab = 0; tab < 3; tab++) {
        final dbKey = _workoutDbKeys[tab];

        // Clear time (metric 0)
        final ctEntries =
            (clearTimeRows as List)
                .where((r) => r['workout_type'] == dbKey)
                .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
                .toList()
              ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
        _cache[_cacheKey(tab, 0)] = ctEntries;

        // Best rep interval (metric 1)
        final riEntries =
            (repIntervalRows as List)
                .where((r) => r['workout_type'] == dbKey)
                .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
                .toList()
              ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
        _cache[_cacheKey(tab, 1)] = riEntries;
      }

      // Fetch lifetime leaderboards
      final repsRows = await _client.from('v_top10_lifetime_reps').select();
      _cache[_cacheKey(3, 0)] = List<Map<String, dynamic>>.from(
        (repsRows as List)
          ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)),
      );

      final victoriesRows = await _client
          .from('v_top10_lifetime_victories')
          .select();
      _cache[_cacheKey(3, 1)] = List<Map<String, dynamic>>.from(
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
            const UserProfileFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutTab(int tabIndex) {
    final selectedMetric = _workoutMetricIndex[tabIndex] ?? 0;
    final entries = _cache[_cacheKey(tabIndex, selectedMetric)] ?? [];
    // Clear time and rep interval are both "lower is better" formatted as time/seconds
    final isTime = selectedMetric == 0;
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
          child: _buildLeaderboardTable(entries: entries, isTime: isTime),
        ),
      ],
    );
  }

  Widget _buildLifetimeTab() {
    final entries = _cache[_cacheKey(3, _lifetimeMetricIndex)] ?? [];
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
          child: _buildLeaderboardTable(entries: entries, isTime: false),
        ),
      ],
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
  }) {
    final itemCount = entries.isEmpty ? 10 : entries.length;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        final hasData = i < entries.length;
        final rank = hasData ? entries[i]['rank'] : i + 1;
        final username = hasData ? (entries[i]['username'] ?? '--') : '--';
        final value = hasData
            ? _formatValue(entries[i]['value'], isTime: isTime)
            : '--';

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
                  '$username',
                  style: TextStyle(
                    color: hasData
                        ? AppTheme.creamWhite
                        : AppTheme.creamWhite.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                ),
              ),
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
