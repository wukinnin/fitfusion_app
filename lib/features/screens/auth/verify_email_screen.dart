import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';


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

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // TODO: Implement Supabase OTP verification
    // 1. Call Supabase verifyOTP with email + code
    // 2. On success, navigate to login
    // 3. On failure, show error

    await Future.delayed(const Duration(seconds: 1)); // Placeholder delay

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/auth/login',
        (route) => route.settings.name == '/auth',
      );
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    // TODO: Implement Supabase resend OTP
    await Future.delayed(const Duration(seconds: 1)); // Placeholder delay

    if (mounted) {
      setState(() => _isResending = false);
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
  }

  @override
  Widget build(BuildContext context) {
    final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';

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
                if (email.isNotEmpty)
                  Text(
                    'Code sent to $email',
                    style: GoogleFonts.cinzel(
                      color: AppTheme.creamWhite,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 40),

                // OTP text field
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: _otpController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
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
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: AppTheme.gold.withValues(alpha: 0.3),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12,
                      ),
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
                  onTap: _isResending ? null : _handleResendCode,
                  child: Text(
                    _isResending ? 'SENDING...' : 'RESEND CODE',
                    style: GoogleFonts.cinzel(
                      color: AppTheme.gold,
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
