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
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildMetricSelector(
          metrics: _workoutMetrics,
          selected: selectedMetric,
          onChanged: (i) => setState(() => _workoutMetricIndex[tabIndex] = i),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildLeaderboardTable(lowerIsBetter: true)),
      ],
    );
  }

  Widget _buildLifetimeTab() {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildMetricSelector(
          metrics: _lifetimeMetrics,
          selected: _lifetimeMetricIndex,
          onChanged: (i) => setState(() => _lifetimeMetricIndex = i),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildLeaderboardTable(lowerIsBetter: false)),
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

  Widget _buildLeaderboardTable({required bool lowerIsBetter}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 10,
      itemBuilder: (context, i) {
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
                  '--',
                  style: TextStyle(
                    color: AppTheme.creamWhite.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '--',
                style: TextStyle(
                  color: AppTheme.creamWhite.withValues(alpha: 0.4),
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
