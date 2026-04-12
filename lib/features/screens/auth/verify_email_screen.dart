import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../services/app_services.dart';
import '../../../services/auth_service.dart';
import '../../../services/service_exception.dart';


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
  late final AuthService _authService;

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
  String _type = 'signup'; // 'signup' or 'recovery'
  bool _argsParsed = false;

  void _parseArgs() {
    if (_argsParsed) return;
    _argsParsed = true;
    _authService = AppServicesScope.of(context).authService;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) {
      _email = args['email'] ?? '';
      _type = args['type'] ?? 'signup';
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

    try {
      final result = await _authService.verifyEmail(
        email: _email,
        code: code,
        type: _type,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result.destination == VerifyDestination.resetPassword) {
          Navigator.pushReplacementNamed(
            context,
            '/auth/reset-password',
            arguments: result.email ?? _email,
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth/login',
            (route) => route.settings.name == '/auth',
          );
        }
      }
    } on AppServiceException catch (e) {
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

    try {
      await _authService.resendVerificationCode(email: _email, type: _type);

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
      body: SafeArea(
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppTheme.gold, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppTheme.gold, width: 2),
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
    );
  }
}
