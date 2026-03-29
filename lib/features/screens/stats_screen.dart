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

  Widget _buildWorkoutStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('SESSION STATS'),
          const SizedBox(height: 8),
          _buildStatCard('Fastest Clear Time', '--'),
          _buildStatCard('Average Clear Time', '--'),
          _buildStatCard('Best Rep Interval', '--'),
          _buildStatCard('Average Rep Interval', '--'),
          const SizedBox(height: 24),
          _buildSectionHeader('LIFETIME STATS'),
          const SizedBox(height: 8),
          _buildStatCard('Rounds Completed', '0'),
          _buildStatCard('Reps Finished', '0'),
          _buildStatCard('Victories', '0'),
          _buildStatCard('Defeats', '0'),
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
          _buildStatCard('Total Sessions', '0'),
          _buildStatCard('Total Reps', '0'),
          _buildStatCard('Total Rounds', '0'),
          _buildStatCard('Total Victories', '0'),
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
