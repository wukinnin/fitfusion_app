import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/user_service.dart';

/// A header widget that displays the current user's username (and optionally
/// their masked email) anchored to the top-center of the screen.
///
/// Reads from the in-memory [UserService] cache so the header renders on the
/// very first frame of any menu screen — no async pop-in. Listens to
/// [UserService.revision] so post-login or post-edit changes propagate
/// without a manual rebuild.
///
/// Display rules:
///   - Username and email render lowercased in Georgia (so descenders /
///     lowercase glyphs look right, unlike Cinzel which is small-caps).
///   - No "Username:" / "Email:" prefix — just the value.
class UserProfileFooter extends StatefulWidget {
  final bool showEmail;
  const UserProfileFooter({super.key, this.showEmail = false});

  @override
  State<UserProfileFooter> createState() => _UserProfileFooterState();
}

class _UserProfileFooterState extends State<UserProfileFooter> {
  @override
  void initState() {
    super.initState();
    // Defensive: if the cache is somehow empty (deep-link, hot-reload, etc.),
    // kick off a fetch. The ValueListenableBuilder below will rebuild when
    // it lands.
    if (!UserService.hasUsername) {
      // ignore: unawaited_futures
      UserService.preload();
    }
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
    return ValueListenableBuilder<int>(
      valueListenable: UserService.revision,
      builder: (context, _, _) {
        final username = UserService.cachedUsername;
        if (username == null) return const SizedBox.shrink();

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username.toLowerCase(),
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    color: AppTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.showEmail && UserService.cachedEmail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _maskEmail(UserService.cachedEmail!).toLowerCase(),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
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
      },
    );
  }
}
