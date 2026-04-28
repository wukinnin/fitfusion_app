import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';

/// A header widget that displays the current user's username (and optionally
/// their masked email) anchored to the top-center of the screen.
///
/// Place this at the top of a [Column] so it sits flush with the top safe
/// area, above the screen's main content.
///
/// When [showEmail] is true the email is displayed below the username with
/// the middle portion masked for privacy (matching the Edit Profile mockup).
class UserProfileFooter extends StatefulWidget {
  final bool showEmail;
  const UserProfileFooter({super.key, this.showEmail = false});

  @override
  State<UserProfileFooter> createState() => _UserProfileFooterState();
}

class _UserProfileFooterState extends State<UserProfileFooter> {
  static final _client = Supabase.instance.client;

  String? _username;
  String? _email;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('users')
          .select('username, email')
          .eq('id', user.id)
          .maybeSingle();

      if (row != null && mounted) {
        setState(() {
          _username = row['username'] as String?;
          _email = row['email'] as String?;
        });
      }
    } catch (_) {}
  }

  String _maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 2) return email;
    final prefix = email.substring(0, 2);
    final domain = email.substring(atIndex);
    final masked = '*' * (atIndex - 2);
    return '$prefix$masked$domain';
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Username:${_username!}',
              style: GoogleFonts.cinzel(
                color: AppTheme.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.showEmail && _email != null) ...[
              const SizedBox(height: 2),
              Text(
                'Email:${_maskEmail(_email!)}',
                style: GoogleFonts.cinzel(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
