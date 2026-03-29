import 'package:flutter/material.dart';

import '../../core/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/game/logo.png',
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  'Exercise is the Gameplay',
                  style: TextStyle(
                    color: AppTheme.creamWhite.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 64),

                // Play button — primary
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/select'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.bloodRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('PLAY',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),

                // Leaderboard button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                      side: const BorderSide(color: AppTheme.gold, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('LEADERBOARD',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),

                // Achievements button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/achievements'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                      side: const BorderSide(color: AppTheme.gold, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('ACHIEVEMENTS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),

                // Stats button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/stats'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                      side: const BorderSide(color: AppTheme.gold, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('STATS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),

                // Settings button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                      side: const BorderSide(color: AppTheme.gold, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('SETTINGS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
