import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/enums.dart';
import '../../core/extensions.dart';
import '../../core/theme.dart';
import '../../services/app_services.dart';
import '../achievements/achievement_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final AchievementServiceBase _service;
  bool _loading = true;
  Set<AchievementId> _unlocked = {};
  bool _servicesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicesReady) return;
    _service = AppServicesScope.of(context).achievementService;
    _servicesReady = true;
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    await _service.init();
    if (mounted) {
      setState(() {
        _unlocked = _service.unlockedAchievements;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      appBar: AppBar(
        backgroundColor: AppTheme.bloodRed,
        title: Text(
          'ACHIEVEMENTS',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _buildAchievementsList(),
    );
  }

  Widget _buildAchievementsList() {
    // Sorted by index (enum declaration order matches README table order)
    final sorted = List<AchievementId>.from(AchievementId.values)
      ..sort((a, b) => a.index.compareTo(b.index));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sorted.length,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final id = sorted[i];
        final unlocked = _unlocked.contains(id);
        return _AchievementTile(
          index: i + 1, // force 1-based numbering in UI (First Blood = #1)
          name: id.displayName,
          description: id.description,
          unlocked: unlocked,
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final int index;
  final String name;
  final String description;
  final bool unlocked;

  const _AchievementTile({
    required this.index,
    required this.name,
    required this.description,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = unlocked
        ? AppTheme.creamWhite
        : AppTheme.creamWhite.withValues(alpha: 0.35);
    final accentColor = unlocked
        ? AppTheme.gold
        : AppTheme.gold.withValues(alpha: 0.25);
    final bgColor = unlocked
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Row(
        children: [
          // Index number
          SizedBox(
            width: 28,
            child: Text(
              '#$index',
              style: GoogleFonts.cinzel(
                color: accentColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Medal icon — only when unlocked
          Icon(
            unlocked ? Icons.military_tech : Icons.military_tech_outlined,
            color: accentColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          // Name + Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.cinzel(
                    color: unlocked ? AppTheme.gold : textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Checkmark for unlocked
          if (unlocked)
            const Icon(Icons.check_circle, color: AppTheme.emerald, size: 22),
        ],
      ),
    );
  }
}
