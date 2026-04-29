import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory cache of the signed-in user's `username` and `email`.
///
/// Many menu screens mount the [UserProfileFooter] (and other widgets that
/// want to show the username) — without a cache, each instance fires its own
/// Supabase round-trip, producing a 100–500 ms blank-then-pop-in for the
/// header on every navigation. By preloading once at splash/login and reading
/// synchronously thereafter, the header is rendered on the very first frame
/// of any menu screen.
///
/// The cache is intentionally process-local (no persistence): on cold start
/// the splash screen calls [preload] before navigating to home, so the gap
/// is paid exactly once per session.
class UserService {
  UserService._();

  static String? _username;
  static String? _email;

  /// Bumps every time the cache changes (preload landing, refresh after a
  /// username edit, clear on logout). Widgets can listen to this via
  /// `ValueListenableBuilder` so they update without a manual rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String? get cachedUsername => _username;
  static String? get cachedEmail => _email;

  /// Whether the cache currently holds a username.
  static bool get hasUsername => _username != null;

  /// Loads username/email from Supabase if not already cached. Idempotent —
  /// safe to call multiple times. Returns once the cache is populated (or
  /// immediately if it already was).
  ///
  /// Errors are swallowed: the footer falls back to rendering nothing rather
  /// than blocking navigation on a transient network blip.
  static Future<void> preload({bool force = false}) async {
    if (!force && _username != null) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await client
          .from('users')
          .select('username, email')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        _username = row['username'] as String?;
        _email = row['email'] as String?;
        _bump();
      }
    } catch (_) {
      // Swallow — leave cache untouched.
    }
  }

  /// Forces a refresh from the backend. Call after the user edits their
  /// username or email so any mounted footers update immediately.
  static Future<void> refresh() => preload(force: true);

  /// Wipes the cache. Call on logout / account deletion.
  static void clear() {
    _username = null;
    _email = null;
    _bump();
  }

  static void _bump() {
    revision.value = revision.value + 1;
  }
}
