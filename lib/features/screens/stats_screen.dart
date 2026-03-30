import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['Squats', 'Jacks', 'Crunches', 'Overall'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWorkoutStatsTab(),
          _buildWorkoutStatsTab(),
          _buildWorkoutStatsTab(),
          _buildOverallTab(),
        ],
      ),
    );
  }

  // Dummy stats for the logged-in player (Vex_Machina) — matches portal dummyData.js
  static const _dummyStats = {
    'squats':   { 'fastestClear': '03:42.110', 'avgClear': '04:15.330', 'bestInterval': '1.62s', 'avgInterval': '2.04s', 'victories': '18', 'defeats': '5', 'rounds': '195', 'reps': '1105' },
    'jacks':    { 'fastestClear': '04:01.220', 'avgClear': '04:38.510', 'bestInterval': '1.78s', 'avgInterval': '2.21s', 'victories': '12', 'defeats': '4', 'rounds': '140', 'reps': '820' },
    'crunches': { 'fastestClear': '04:18.450', 'avgClear': '04:52.110', 'bestInterval': '1.85s', 'avgInterval': '2.35s', 'victories': '10', 'defeats': '3', 'rounds': '120', 'reps': '710' },
  };
  static const _workoutKeyByTab = ['squats', 'jacks', 'crunches'];

  Widget _buildWorkoutStatsTab() {
    final tabIndex = _tabController.index.clamp(0, 2);
    final key = _workoutKeyByTab[tabIndex];
    final s = _dummyStats[key]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('SESSION STATS'),
          const SizedBox(height: 8),
          _buildStatCard('Fastest Clear Time', s['fastestClear']!),
          _buildStatCard('Average Clear Time', s['avgClear']!),
          _buildStatCard('Best Rep Interval', s['bestInterval']!),
          _buildStatCard('Average Rep Interval', s['avgInterval']!),
          const SizedBox(height: 24),
          _buildSectionHeader('LIFETIME STATS'),
          const SizedBox(height: 8),
          _buildStatCard('Rounds Completed', s['rounds']!),
          _buildStatCard('Reps Finished', s['reps']!),
          _buildStatCard('Victories', s['victories']!),
          _buildStatCard('Defeats', s['defeats']!),
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
          _buildStatCard('Total Sessions', '52'),
          _buildStatCard('Total Reps', '2635'),
          _buildStatCard('Total Rounds', '455'),
          _buildStatCard('Total Victories', '40'),
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
