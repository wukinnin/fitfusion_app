import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _currentPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
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
          'DELETE ACCOUNT',
          style: GoogleFonts.cinzelDecorative(
            color: AppTheme.crimson,
            fontSize: 18,
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.crimson.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.crimson, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'ARE YOU SURE YOU WANT TO DELETE YOUR ACCOUNT?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.crimson,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All data is cleared and disassociates your email and username in the game. This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.creamWhite.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.creamWhite,
                        side: BorderSide(
                            color:
                                AppTheme.creamWhite.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        // Visual only — no action
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.crimson,
                        foregroundColor: AppTheme.creamWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'DELETE',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
