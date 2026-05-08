import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../features/game/game_launch_args.dart';
import '../../features/knight/knight_disposition.dart';
import '../../features/knight/knight_service.dart';
import '../../services/app_bgm_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../widgets/fitfusion_animated_background.dart';
import '../../widgets/user_profile_footer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final _client = Supabase.instance.client;

  bool _showTutorial = true;
  double _volume = 1.0;
  bool _loading = true;
  KnightDisposition? _testDisposition;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final row = await _client
          .from('users')
          .select('show_tutorial')
          .eq('id', user.id)
          .maybeSingle();

      if (row != null) {
        _showTutorial = (row['show_tutorial'] as bool?) ?? true;
      }

      _volume = AppBgmService.instance.globalVolume;
    } catch (e) {
      assert(() {
        debugPrint('[SettingsScreen] Failed to load settings: $e');
        return true;
      }());
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateShowTutorial(bool value) async {
    setState(() => _showTutorial = value);

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('users')
          .update({'show_tutorial': value})
          .eq('id', user.id);
    } catch (e) {
      assert(() {
        debugPrint('[SettingsScreen] Failed to update show_tutorial: $e');
        return true;
      }());
    }
  }

  Future<void> _handleLogOut() async {
    // Local-scope sign-out: clears the on-device session synchronously and
    // does NOT make a network round-trip to revoke server-side. Using the
    // default (global) scope means the call hangs for the full HTTP
    // timeout on flaky / offline networks, making the button feel dead.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      assert(() {
        debugPrint('[SettingsScreen] signOut failed: $e');
        return true;
      }());
    }

    // Wipe the cached username/email so the welcome/login screens don't
    // briefly flash the previous user's header.
    UserService.clear();

    // Fire-and-forget: cancelling pending Knight pings shouldn't block
    // navigation. The plugin lazy-initializes on first use, which can
    // take a noticeable beat on cold platform channels.
    // ignore: unawaited_futures
    NotificationService.instance.cancelAll();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  Future<void> _updateVolume(double value) async {
    setState(() => _volume = value);
    await AppBgmService.instance.setGlobalVolume(value);
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
          'SETTINGS',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FitFusionAnimatedBackground(
        child: Column(
          children: [
            const UserProfileFooter(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Game Tutorial Toggle
                          _buildSectionHeader('GAME'),
                          const SizedBox(height: 8),
                          _buildToggleTile(
                            label: 'Show Tutorial at Startup',
                            value: _showTutorial,
                            onChanged: _updateShowTutorial,
                          ),
                          const SizedBox(height: 16),

                          // Volume Slider
                          _buildSectionHeader('AUDIO'),
                          const SizedBox(height: 8),
                          _buildVolumeSlider(),
                          const SizedBox(height: 24),

                          // Edit Profile
                          _buildSectionHeader('ACCOUNT'),
                          const SizedBox(height: 8),
                          _buildNavigationTile(
                            icon: Icons.person_outline,
                            label: 'Edit Profile',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/settings/edit-profile',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Log Out
                          _buildActionTile(
                            icon: Icons.logout,
                            label: 'Log Out',
                            color: AppTheme.crimson,
                            onTap: () => _handleLogOut(),
                          ),
                          const SizedBox(height: 24),

                          // Dev / Test
                          _buildSectionHeader('DEV / TEST'),
                          const SizedBox(height: 8),
                          _buildTestDispositionRow(),
                          const SizedBox(height: 12),
                          _buildActionTile(
                            icon: Icons.notifications_active,
                            label: 'Send Test Notification',
                            color: AppTheme.emerald,
                            onTap: () => _handleTestNotification(),
                          ),
                          const SizedBox(height: 8),
                          _buildActionTile(
                            icon: Icons.auto_awesome,
                            label: 'Play Bonus Test',
                            color: AppTheme.gold,
                            onTap: () => _launchBonusTest(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
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
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.gold,
            activeTrackColor: AppTheme.gold.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.creamWhite.withValues(alpha: 0.5),
            inactiveTrackColor: Colors.black.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Volume',
                style: TextStyle(
                  color: AppTheme.creamWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(_volume * 100).round()}%',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.gold,
              inactiveTrackColor: AppTheme.gold.withValues(alpha: 0.2),
              thumbColor: AppTheme.gold,
              overlayColor: AppTheme.gold.withValues(alpha: 0.15),
            ),
            child: Slider(value: _volume, onChanged: _updateVolume),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.creamWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.gold.withValues(alpha: 0.6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _setTestDisposition(KnightDisposition d) {
    setState(() => _testDisposition = d);
    KnightService.setTestOverride(d);
  }

  void _clearTestDisposition() {
    setState(() => _testDisposition = null);
    KnightService.clearTestOverride();
  }

  Future<void> _handleTestNotification() async {
    final disposition = _testDisposition ?? KnightDisposition.veryActive;
    await NotificationService.instance.sendTestNotification(disposition);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test notification sent (${disposition.displayName})',
            style: GoogleFonts.cinzel(color: AppTheme.creamWhite),
          ),
        ),
      );
    }
  }

  void _launchBonusTest() {
    Navigator.pushNamed(
      context,
      '/game',
      arguments: const GameLaunchArgs(
        workoutType: WorkoutType.jumpingJacks,
        cooldownSeconds: 2,
        bonusOnlyTestMode: true,
      ),
    );
  }

  Widget _buildTestDispositionRow() {
    final dispositions = KnightDisposition.values;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Override Knight Disposition',
            style: const TextStyle(
              color: AppTheme.creamWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in dispositions)
                ChoiceChip(
                  label: Text(
                    d.displayName,
                    style: GoogleFonts.cinzel(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _testDisposition == d
                          ? AppTheme.bloodRed
                          : AppTheme.gold,
                    ),
                  ),
                  selected: _testDisposition == d,
                  onSelected: (selected) {
                    if (selected) {
                      _setTestDisposition(d);
                    } else {
                      _clearTestDisposition();
                    }
                  },
                  selectedColor: AppTheme.gold,
                  backgroundColor: AppTheme.midnightNavy,
                  side: const BorderSide(color: AppTheme.gold),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ChoiceChip(
                label: Text(
                  'Reset',
                  style: GoogleFonts.cinzel(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _testDisposition == null
                        ? AppTheme.bloodRed
                        : AppTheme.crimson,
                  ),
                ),
                selected: _testDisposition == null,
                onSelected: (_) => _clearTestDisposition(),
                selectedColor: AppTheme.crimson,
                backgroundColor: AppTheme.midnightNavy,
                side: const BorderSide(color: AppTheme.crimson),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
