import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Per-workout metric index: 0 = Clear Time, 1 = Best Rep Interval
  final Map<int, int> _workoutMetricIndex = {0: 0, 1: 0, 2: 0};
  // Lifetime metric index: 0 = Total Reps, 1 = Total Victories
  int _lifetimeMetricIndex = 0;

  static const _workoutTabs = ['Squats', 'Jacks', 'Crunches', 'Lifetime'];
  static const _workoutMetrics = ['Clear Time', 'Best Rep Interval'];
  static const _lifetimeMetrics = ['Total Reps', 'Total Victories'];

  // Dummy leaderboard data — consistent with portal dummyData.js
  // Keys: [tabIndex][metricIndex] for workout, [metricIndex] for lifetime
  static const _workoutData = <int, Map<int, List<Map<String, String>>>>{
    // Squats
    0: {
      0: [ // Clear Time (ascending — lower is better)
        {'name': 'Neon_Ronin',    'val': '03:28.550'},
        {'name': 'Shadow_Step',   'val': '03:35.330'},
        {'name': 'Vex_Machina',   'val': '03:42.110'},
        {'name': 'Cinder_Sage',   'val': '03:48.110'},
        {'name': 'Grog_Nasty',    'val': '03:55.440'},
        {'name': 'Lunar_Squire',  'val': '04:05.320'},
        {'name': 'Fia_Fireheart', 'val': '04:15.110'},
        {'name': 'Zero_Kelvin',   'val': '04:28.220'},
        {'name': 'Mana_Miser',    'val': '04:38.110'},
        {'name': 'Loot_Goblin',   'val': '04:45.220'},
      ],
      1: [ // Best Rep Interval (ascending)
        {'name': 'Neon_Ronin',    'val': '1.45s'},
        {'name': 'Shadow_Step',   'val': '1.55s'},
        {'name': 'Vex_Machina',   'val': '1.62s'},
        {'name': 'Cinder_Sage',   'val': '1.68s'},
        {'name': 'Grog_Nasty',    'val': '1.70s'},
        {'name': 'Lunar_Squire',  'val': '1.75s'},
        {'name': 'Fia_Fireheart', 'val': '1.82s'},
        {'name': 'Zero_Kelvin',   'val': '1.90s'},
        {'name': 'Mana_Miser',    'val': '1.98s'},
        {'name': 'Loot_Goblin',   'val': '2.02s'},
      ],
    },
    // Jumping Jacks
    1: {
      0: [
        {'name': 'Neon_Ronin',    'val': '03:38.220'},
        {'name': 'Shadow_Step',   'val': '03:48.110'},
        {'name': 'Cinder_Sage',   'val': '03:55.220'},
        {'name': 'Vex_Machina',   'val': '04:01.220'},
        {'name': 'Lunar_Squire',  'val': '04:12.150'},
        {'name': 'Grog_Nasty',    'val': '04:20.110'},
        {'name': 'Fia_Fireheart', 'val': '04:25.330'},
        {'name': 'Zero_Kelvin',   'val': '04:35.110'},
        {'name': 'Mana_Miser',    'val': '04:45.220'},
        {'name': 'Loot_Goblin',   'val': '04:52.110'},
      ],
      1: [
        {'name': 'Neon_Ronin',    'val': '1.52s'},
        {'name': 'Shadow_Step',   'val': '1.65s'},
        {'name': 'Cinder_Sage',   'val': '1.72s'},
        {'name': 'Vex_Machina',   'val': '1.78s'},
        {'name': 'Lunar_Squire',  'val': '1.81s'},
        {'name': 'Fia_Fireheart', 'val': '1.88s'},
        {'name': 'Grog_Nasty',    'val': '1.95s'},
        {'name': 'Zero_Kelvin',   'val': '1.95s'},
        {'name': 'Mana_Miser',    'val': '2.04s'},
        {'name': 'Loot_Goblin',   'val': '2.08s'},
      ],
    },
    // Side Crunches
    2: {
      0: [
        {'name': 'Neon_Ronin',    'val': '03:50.110'},
        {'name': 'Shadow_Step',   'val': '03:58.220'},
        {'name': 'Cinder_Sage',   'val': '04:05.110'},
        {'name': 'Vex_Machina',   'val': '04:18.450'},
        {'name': 'Lunar_Squire',  'val': '04:22.080'},
        {'name': 'Fia_Fireheart', 'val': '04:30.220'},
        {'name': 'Grog_Nasty',    'val': '04:35.220'},
        {'name': 'Zero_Kelvin',   'val': '04:42.330'},
        {'name': 'Mana_Miser',    'val': '04:52.110'},
        {'name': 'Loot_Goblin',   'val': '05:00.220'},
      ],
      1: [
        {'name': 'Neon_Ronin',    'val': '1.60s'},
        {'name': 'Shadow_Step',   'val': '1.72s'},
        {'name': 'Cinder_Sage',   'val': '1.78s'},
        {'name': 'Vex_Machina',   'val': '1.85s'},
        {'name': 'Lunar_Squire',  'val': '1.90s'},
        {'name': 'Fia_Fireheart', 'val': '1.92s'},
        {'name': 'Grog_Nasty',    'val': '2.00s'},
        {'name': 'Zero_Kelvin',   'val': '2.02s'},
        {'name': 'Mana_Miser',    'val': '2.08s'},
        {'name': 'Loot_Goblin',   'val': '2.12s'},
      ],
    },
  };

  static const _lifetimeData = <int, List<Map<String, String>>>{
    0: [ // Total Reps (descending — higher is better)
      {'name': 'Vex_Machina',   'val': '2635'},
      {'name': 'Lunar_Squire',  'val': '2395'},
      {'name': 'Grog_Nasty',    'val': '2330'},
      {'name': 'Fia_Fireheart', 'val': '2200'},
      {'name': 'Neon_Ronin',    'val': '1840'},
      {'name': 'Zero_Kelvin',   'val': '1640'},
      {'name': 'Shadow_Step',   'val': '1560'},
      {'name': 'Mana_Miser',    'val': '1510'},
      {'name': 'Cinder_Sage',   'val': '1485'},
      {'name': 'Blinker_Fluid', 'val': '1350'},
    ],
    1: [ // Total Victories (descending)
      {'name': 'Vex_Machina',   'val': '40'},
      {'name': 'Lunar_Squire',  'val': '34'},
      {'name': 'Grog_Nasty',    'val': '31'},
      {'name': 'Fia_Fireheart', 'val': '30'},
      {'name': 'Neon_Ronin',    'val': '27'},
      {'name': 'Shadow_Step',   'val': '24'},
      {'name': 'Zero_Kelvin',   'val': '21'},
      {'name': 'Cinder_Sage',   'val': '21'},
      {'name': 'Mana_Miser',    'val': '18'},
      {'name': 'Blinker_Fluid', 'val': '15'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          labelStyle: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 12),
          tabs: _workoutTabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWorkoutTab(0),
          _buildWorkoutTab(1),
          _buildWorkoutTab(2),
          _buildLifetimeTab(),
        ],
      ),
    );
  }

  Widget _buildWorkoutTab(int tabIndex) {
    final selectedMetric = _workoutMetricIndex[tabIndex] ?? 0;
    final rows = _workoutData[tabIndex]?[selectedMetric] ?? [];
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildMetricSelector(
          metrics: _workoutMetrics,
          selected: selectedMetric,
          onChanged: (i) => setState(() => _workoutMetricIndex[tabIndex] = i),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildLeaderboardTable(rows)),
      ],
    );
  }

  Widget _buildLifetimeTab() {
    final rows = _lifetimeData[_lifetimeMetricIndex] ?? [];
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildMetricSelector(
          metrics: _lifetimeMetrics,
          selected: _lifetimeMetricIndex,
          onChanged: (i) => setState(() => _lifetimeMetricIndex = i),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildLeaderboardTable(rows)),
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeaderboardTable(List<Map<String, String>> rows) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
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
                  '#${i + 1}',
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
                  row['name'] ?? '--',
                  style: TextStyle(
                    color: AppTheme.creamWhite,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                row['val'] ?? '--',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
