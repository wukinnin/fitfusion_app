import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums.dart';
import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';
import '../../../widgets/user_profile_footer.dart';
import '../../multiplayer/p2_session_cache.dart';
import '../../multiplayer/p2_verification_service.dart';

/// Collects Player 2's email address. If a valid cached P2 already exists
/// for this app session, the user can recycle it and skip the OTP step.
/// Otherwise, requesting a code routes to the existing OTP screen using
/// `type: 'multiplayer_p2'`.
class P2EmailScreen extends StatefulWidget {
  const P2EmailScreen({super.key});

  @override
  State<P2EmailScreen> createState() => _P2EmailScreenState();
}

class _P2EmailScreenState extends State<P2EmailScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _errorMessage;

  WorkoutType _workoutType = WorkoutType.jumpingJacks;
  bool _argsParsed = false;

  void _parseArgs() {
    if (_argsParsed) return;
    _argsParsed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['workoutType'] is WorkoutType) {
      _workoutType = args['workoutType'] as WorkoutType;
    }
    final cached = P2SessionCache.instance.email;
    if (cached != null && _emailController.text.isEmpty) {
      _emailController.text = cached;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    // Recycle path — skip OTP entirely if this email is already verified
    // for the current app session.
    if (P2SessionCache.instance.isValid(email)) {
      _proceedToCooldown(P2SessionCache.instance.userId!, email);
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await P2VerificationService.sendOtp(email);
      if (!mounted) return;
      setState(() => _isSending = false);
      // Reuse the existing OTP screen, signalled by type.
      Navigator.pushNamed(
        context,
        '/auth/verify',
        arguments: {
          'email': email,
          'type': 'multiplayer_p2',
          'workoutType': _workoutType,
        },
      );
    } on P2VerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _useCachedP2() {
    final cached = P2SessionCache.instance;
    if (!cached.hasVerifiedP2) return;
    _proceedToCooldown(cached.userId!, cached.email!);
  }

  void _proceedToCooldown(String p2UserId, String p2Email) {
    Navigator.pushNamed(
      context,
      '/select/cooldown',
      arguments: {
        'workoutType': _workoutType,
        'isMultiplayer': true,
        'player2UserId': p2UserId,
        'player2Email': p2Email,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _parseArgs();
    final hasCached = P2SessionCache.instance.hasVerifiedP2;

    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      appBar: AppBar(
        backgroundColor: AppTheme.bloodRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PLAYER 2',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 18,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "Enter your Player 2's email.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: AppTheme.creamWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'They must already have a FitFusion account. '
                      "We'll send a 6-digit code to confirm it's really them.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: AppTheme.creamWhite.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailController,
                      enabled: !_isSending,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(
                        color: AppTheme.creamWhite,
                        fontFamily: 'Georgia',
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Player 2 Email',
                        labelStyle: GoogleFonts.cinzel(
                          color: AppTheme.gold,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.gold,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.gold,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: AppTheme.crimson,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _handleSendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.bloodRed,
                          disabledBackgroundColor:
                              AppTheme.gold.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.bloodRed,
                                ),
                              )
                            : const Text(
                                'SEND CODE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    if (hasCached) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: _isSending ? null : _useCachedP2,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          side: const BorderSide(
                            color: AppTheme.gold,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'USE LAST PLAYER 2 (${P2SessionCache.instance.email})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
