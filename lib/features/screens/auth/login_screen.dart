import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or username is required';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    try {
      // Determine if identifier is email or username
      String email;
      if (identifier.contains('@')) {
        email = identifier;
      } else {
        // Resolve username to email via RPC
        final resolved = await supabase.rpc(
          'get_email_by_username',
          params: {'p_username': identifier},
        );
        if (resolved == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showError('Username not found');
          }
          return;
        }
        email = resolved as String;
      }

      // Sign in with Supabase Auth
      await supabase.auth.signInWithPassword(email: email, password: password);

      // Check if email is verified
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final rows = await supabase
            .from('users')
            .select('is_email_verified')
            .eq('id', userId)
            .limit(1);
        if (rows.isNotEmpty && rows[0]['is_email_verified'] == false) {
          // Not verified — sign out, resend OTP, immediately redirect
          await supabase.auth.signOut();
          supabase.auth.resend(type: OtpType.signup, email: email);
          if (mounted) {
            setState(() => _isLoading = false);
            _showError('Email not yet verified');
            Navigator.pushNamed(
              context,
              '/auth/verify',
              arguments: {'email': email, 'type': 'signup'},
            );
          }
          return;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('An unexpected error occurred');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.crimson),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      body: FitFusionAnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'LOGIN',
                        style: GoogleFonts.cinzelDecorative(
                          color: AppTheme.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email or Username
                    _buildLabel('EMAIL OR USERNAME'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _identifierController,
                      validator: _validateIdentifier,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    _buildLabel('PASSWORD'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _passwordController,
                      validator: _validatePassword,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/auth/forgot-password',
                        ),
                        child: Text(
                          'FORGOT PASSWORD?',
                          style: GoogleFonts.cinzel(
                            color: AppTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login button
                    Center(
                      child: SizedBox(
                        width: 180,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.gold,
                            side: const BorderSide(
                              color: AppTheme.gold,
                              width: 2,
                            ),
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
                                  'LOGIN',
                                  style: GoogleFonts.cinzelDecorative(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Don't have an account? Sign Up
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          '/auth/signup',
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.cinzel(
                              color: AppTheme.creamWhite,
                              fontSize: 12,
                            ),
                            children: [
                              const TextSpan(text: "DON'T HAVE AN ACCOUNT? "),
                              TextSpan(
                                text: 'SIGN UP',
                                style: GoogleFonts.cinzel(
                                  color: AppTheme.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.cinzel(
        color: AppTheme.gold,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(
        color: AppTheme.gold,
        fontSize: 14,
        fontFamily: 'Georgia',
        fontWeight: FontWeight.normal,
      ),
      cursorColor: AppTheme.gold,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.crimson, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.crimson, width: 2),
        ),
        errorStyle: const TextStyle(color: AppTheme.brightGold, fontSize: 11),
      ),
    );
  }
}
