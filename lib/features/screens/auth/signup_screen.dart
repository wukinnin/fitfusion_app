import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';
import '../../../widgets/fitfusion_animated_background.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 10) {
      return 'Must be at least 10 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      // Check email uniqueness
      final emailExists =
          await supabase.rpc('check_email_exists', params: {'p_email': email})
              as bool;
      if (emailExists) {
        // Email exists — check if verified
        // If not verified, redirect to verify screen
        final rows = await supabase
            .from('users')
            .select('is_email_verified')
            .eq('email', email)
            .limit(1);
        if (rows.isNotEmpty && rows[0]['is_email_verified'] == false) {
          // Resend OTP and immediately redirect to verify
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
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Email is already taken');
        }
        return;
      }

      // Check username uniqueness (case-insensitive) via RPC
      final existingEmail = await supabase.rpc(
        'get_email_by_username',
        params: {'p_username': username},
      );
      if (existingEmail != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Username is already taken');
        }
        return;
      }

      // Sign up with Supabase Auth — username passed via metadata
      // Trigger handle_auth_user_created picks up username from raw_user_meta_data
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamed(
          context,
          '/auth/verify',
          arguments: {'email': email, 'type': 'signup'},
        );
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
                        'SIGN UP',
                        style: GoogleFonts.cinzelDecorative(
                          color: AppTheme.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Username
                    _buildLabel('USERNAME'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _usernameController,
                      validator: _validateUsername,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // Email
                    _buildLabel('EMAIL'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _emailController,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
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
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 4),
                    Text(
                      'Minimum 10 characters',
                      style: TextStyle(
                        color: AppTheme.creamWhite.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    _buildLabel('CONFIRM PASSWORD'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      validator: _validateConfirmPassword,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Sign Up button
                    Center(
                      child: SizedBox(
                        width: 180,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleSignup,
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
                                  'SIGN UP',
                                  style: GoogleFonts.cinzelDecorative(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Already have an account? Login
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          '/auth/login',
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.cinzel(
                              color: AppTheme.creamWhite,
                              fontSize: 12,
                            ),
                            children: [
                              const TextSpan(text: 'ALREADY HAVE AN ACCOUNT? '),
                              TextSpan(
                                text: 'LOGIN',
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
