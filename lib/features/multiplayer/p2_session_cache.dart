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

  String? get email => _email;
  String? get userId => _userId;
  DateTime? get verifiedAt => _verifiedAt;
  bool get hasVerifiedP2 => _userId != null && _email != null;

  /// Returns true if [email] matches the cached verified P2 (case-insensitive).
  /// Lifetime is the app process — a kill or logout invalidates the cache.
  bool isValid(String email) {
    if (!hasVerifiedP2) return false;
    return _email!.toLowerCase() == email.trim().toLowerCase();
  }

  void recordVerified({required String email, required String userId}) {
    _email = email.trim();
    _userId = userId;
    _verifiedAt = DateTime.now();
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
  }
}
