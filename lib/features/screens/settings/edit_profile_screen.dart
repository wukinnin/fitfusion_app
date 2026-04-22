import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';
import '../../../widgets/user_profile_footer.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

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
          'EDIT PROFILE',
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTile(
                    context,
                    icon: Icons.lock_outline,
                    label: 'Reset Password',
                    route: '/settings/reset-password',
                  ),
                  const SizedBox(height: 10),
                  _buildTile(
                    context,
                    icon: Icons.badge_outlined,
                    label: 'Change Username',
                    route: '/settings/change-username',
                  ),
                  const SizedBox(height: 10),
                  _buildTile(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Change Email',
                    route: '/settings/change-email',
                  ),
                  const SizedBox(height: 10),
                  _buildTile(
                    context,
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete Account',
                    route: '/settings/delete-account',
                    color: AppTheme.crimson,
                  ),
                ],
              ),
            ),
            const Spacer(),
            const UserProfileFooter(showEmail: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    Color? color,
  }) {
    final accent = color ?? AppTheme.gold;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: accent, size: 24),
          ],
        ),
      ),
    );
  }
}
