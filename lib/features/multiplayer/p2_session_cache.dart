/// In-memory cache of the most recently verified Player 2 for the current
/// app process.
///
/// The cache is intentionally **not persisted** — it's cleared on logout and
/// when the app is killed. While the cache is valid, the multiplayer flow
/// can skip the OTP step (the "recycle" affordance in the spec).
class P2SessionCache {
  P2SessionCache._();
  static final P2SessionCache instance = P2SessionCache._();

  String? _email;
  String? _userId;
  DateTime? _verifiedAt;

  /// P1's refresh token, stashed before the OTP send so we can restore P1's
  /// session right after `verifyOTP` swaps the global session over to P2.
  String? _pendingP1RefreshToken;

  /// P2's refresh token, captured at the moment `verifyOTP` succeeds (before
  /// we swap the global session back to P1). Used at end-of-session to spin
  /// up a transient SupabaseClient authenticated as P2 so the partner row
  /// can be inserted into `public.sessions` without violating the
  /// `sessions_insert_own` RLS policy. Memory-only; cleared on logout.
  String? _p2RefreshToken;

  String? get email => _email;
  String? get userId => _userId;
  DateTime? get verifiedAt => _verifiedAt;
  bool get hasVerifiedP2 => _userId != null && _email != null;

  /// Most recently observed refresh token for the verified P2. Rotates each
  /// time the transient client refreshes — see [updateP2RefreshToken].
  String? get p2RefreshToken => _p2RefreshToken;

  /// Returns true if [email] matches the cached verified P2 (case-insensitive).
  /// Lifetime is the app process — a kill or logout invalidates the cache.
  bool isValid(String email) {
    if (!hasVerifiedP2) return false;
    return _email!.toLowerCase() == email.trim().toLowerCase();
  }

  void recordVerified({
    required String email,
    required String userId,
    String? refreshToken,
  }) {
    _email = email.trim();
    _userId = userId;
    _verifiedAt = DateTime.now();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _p2RefreshToken = refreshToken;
    }
  }

  /// Replace the cached P2 refresh token. Supabase rotates refresh tokens on
  /// every use by default, so the transient client must call this after
  /// each `setSession` so the next multiplayer save still has a valid token.
  /// A null/empty argument is treated as a no-op so callers don't
  /// accidentally wipe a still-valid token if `currentSession` is briefly
  /// missing — use [clearP2RefreshToken] for explicit invalidation.
  void updateP2RefreshToken(String? refreshToken) {
    if (refreshToken == null || refreshToken.isEmpty) return;
    _p2RefreshToken = refreshToken;
  }

  /// Explicitly forget the cached P2 refresh token (e.g. after we've seen
  /// the auth server reject it). The verified-P2 identity stays in place
  /// so the recycle UI still shows their email; only the token is dropped,
  /// which forces the next multiplayer match to re-OTP.
  void clearP2RefreshToken() {
    _p2RefreshToken = null;
  }

  void stashPendingP1RefreshToken(String token) {
    _pendingP1RefreshToken = token;
  }

  String? consumePendingP1RefreshToken() {
    final t = _pendingP1RefreshToken;
    _pendingP1RefreshToken = null;
    return t;
  }

  String? peekPendingP1RefreshToken() => _pendingP1RefreshToken;

  /// Clears all cached state. Call on logout.
  void clear() {
    _email = null;
    _userId = null;
    _verifiedAt = null;
    _pendingP1RefreshToken = null;
    _p2RefreshToken = null;
  }
}
