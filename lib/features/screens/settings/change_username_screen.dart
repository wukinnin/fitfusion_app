import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';
import '../../../widgets/user_profile_footer.dart';

class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _currentPasswordController = TextEditingController();
  final _newUsernameController = TextEditingController();
  final _confirmUsernameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newUsernameController.dispose();
    _confirmUsernameController.dispose();
    super.dispose();
  }

  Future<void> _handleChangeUsername() async {
    final currentPw = _currentPasswordController.text;
    final newUsername = _newUsernameController.text.trim();
    final confirmUsername = _confirmUsernameController.text.trim();

    if (currentPw.isEmpty || newUsername.isEmpty || confirmUsername.isEmpty) {
      _showError('All fields are required');
      return;
    }
    if (newUsername.length < 3) {
      _showError('Username must be at least 3 characters');
      return;
    }
    if (newUsername != confirmUsername) {
      _showError('Usernames do not match');
      return;
    }

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final email = supabase.auth.currentUser!.email!;
    final userId = supabase.auth.currentUser!.id;

    try {
      // Re-authenticate with current password
      await supabase.auth.signInWithPassword(email: email, password: currentPw);

      // Check username uniqueness (case-insensitive) via RPC
      final existingEmail = await supabase.rpc(
        'get_email_by_username',
        params: {'p_username': newUsername},
      );
      if (existingEmail != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Username is already taken');
        }
        return;
      }

      // Update username in public.users table
      await supabase
          .from('users')
          .update({'username': newUsername})
          .eq('id', userId);

      // Update auth user metadata
      await supabase.auth.updateUser(
        UserAttributes(data: {'username': newUsername}),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Username updated successfully',
              style: GoogleFonts.cinzel(color: AppTheme.bloodRed),
            ),
            backgroundColor: AppTheme.gold,
          ),
        );
        Navigator.pop(context);
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
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.crimson,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bloodRed,
      appBar: AppBar(
        backgroundColor: AppTheme.bloodRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CHANGE USERNAME',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppTheme.creamWhite),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(
                  color: AppTheme.creamWhite.withValues(alpha: 0.6),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.gold, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppTheme.gold.withValues(alpha: 0.6),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _newUsernameController,
              label: 'New Username',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmUsernameController,
              label: 'Confirm New Username',
            ),
            const SizedBox(height: 8),
            Text(
              'Must be unique and not already taken',
              style: TextStyle(
                color: AppTheme.creamWhite.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleChangeUsername,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.bloodRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppTheme.bloodRed,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CHANGE USERNAME',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const UserProfileFooter(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.creamWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.creamWhite.withValues(alpha: 0.6),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppTheme.gold.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.gold, width: 2),
        ),
      ),
    );
  }
}
