import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  void _startCooldown() {
    _resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String _email = '';
  String _type = 'signup'; // 'signup', 'recovery', or 'email_change'

  bool _returnOnSuccess = false;
  bool _argsParsed = false;

  void _parseArgs() {
    if (_argsParsed) return;
    _argsParsed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _email = args['email']?.toString() ?? '';
      _type = args['type']?.toString() ?? 'signup';
      _returnOnSuccess = args['returnOnSuccess'] == true;
    }
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter at least 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      final OtpType otpType;
      switch (_type) {
        case 'recovery':
          otpType = OtpType.recovery;
          break;
        case 'email_change':
          otpType = OtpType.emailChange;
          break;
        default:
          otpType = OtpType.signup;
      }

      await supabase.auth.verifyOTP(email: _email, token: code, type: otpType);

      if (_type == 'signup') {
        // Mark email as verified in public.users
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase
              .from('users')
              .update({'is_email_verified': true})
              .eq('id', userId);
        }
        // Sign out so user logs in fresh
        await supabase.auth.signOut();
      } else if (_type == 'email_change') {
        // Sync public.users.email with newly-verified auth.users.email
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase
              .from('users')
              .update({'email': _email})
              .eq('id', userId);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (_returnOnSuccess) {
          // Caller wants control returned (e.g. Change Email flow)
          Navigator.pop(context, true);
          return;
        }
        if (_type == 'recovery') {
          // Recovery: proceed to reset password screen
          Navigator.pushReplacementNamed(
            context,
            '/auth/reset-password',
            arguments: _email,
          );
        } else {
          // Signup: go to login
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth/login',
            (route) => route.settings.name == '/auth',
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification failed';
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      if (_type == 'recovery') {
        await supabase.auth.resetPasswordForEmail(_email);
      } else if (_type == 'email_change') {
        await supabase.auth.resend(type: OtpType.emailChange, email: _email);
      } else {
        await supabase.auth.resend(type: OtpType.signup, email: _email);
      }

      if (mounted) {
        setState(() => _isResending = false);
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification code resent',
              style: GoogleFonts.cinzel(color: AppTheme.bloodRed),
            ),
            backgroundColor: AppTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to resend code'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _parseArgs();

    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      body: FitFusionAnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'VERIFY EMAIL',
                    style: GoogleFonts.cinzelDecorative(
                      color: AppTheme.gold,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_email.isNotEmpty)
                    Text(
                      'Code sent to $_email',
                      style: GoogleFonts.cinzel(
                        color: AppTheme.creamWhite,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 40),

                  // OTP text field
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      controller: _otpController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 22,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.normal,
                        letterSpacing: 12,
                      ),
                      cursorColor: AppTheme.gold,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.gold,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.gold,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error message
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.cinzel(
                        color: AppTheme.brightGold,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Verify button
                  SizedBox(
                    width: 180,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleVerify,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.gold,
                        side: const BorderSide(color: AppTheme.gold, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppTheme.gold,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'VERIFY',
                              style: GoogleFonts.cinzelDecorative(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Resend Code
                  GestureDetector(
                    onTap: (_isResending || _resendCooldown > 0)
                        ? null
                        : _handleResendCode,
                    child: Text(
                      _isResending
                          ? 'SENDING...'
                          : _resendCooldown > 0
                          ? 'RESEND CODE (${_resendCooldown}s)'
                          : 'RESEND CODE',
                      style: GoogleFonts.cinzel(
                        color: _resendCooldown > 0
                            ? AppTheme.gold.withValues(alpha: 0.4)
                            : AppTheme.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
