import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newUsernameController.dispose();
    _confirmUsernameController.dispose();
    super.dispose();
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
      body: SingleChildScrollView(
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
                onPressed: () {
                  // Visual only — no action
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.bloodRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CHANGE USERNAME',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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
