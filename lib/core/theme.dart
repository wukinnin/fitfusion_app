import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Static color constants for use in Flame components (which cannot use ThemeData)
  static const Color gold = Color(0xFFFFD700);
  static const Color bloodRed = Color(0xFF660000);
  static const Color crimson = Color(0xFFB71C1C);
  static const Color emerald = Color(0xFF2E7D32);
  static const Color parchment = Color(0xFFFFF8E1);
  static const Color brightGold = Color(0xFFFFEE58);
  static const Color creamWhite = Color(0xFFFFFDE7);
  static const Color midnightNavy = Color(0xFF0D1B3E);
  static const Color parchmentOverlay = Color(0x26FFF8E1);

  static final PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const CupertinoPageTransitionsBuilder(),
        },
      );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: bloodRed,
        secondary: gold,
        surface: midnightNavy,
        surfaceContainerHighest: midnightNavy,
        error: crimson,
        onPrimary: creamWhite,
        onSecondary: bloodRed,
        onSurface: creamWhite,
        onError: creamWhite,
      ),
      scaffoldBackgroundColor: bloodRed,
      canvasColor: bloodRed,
      cardColor: midnightNavy,
      splashColor: gold.withValues(alpha: 0.12),
      highlightColor: gold.withValues(alpha: 0.08),
      pageTransitionsTheme: _pageTransitionsTheme,
      textTheme: GoogleFonts.cinzelTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: creamWhite),
          displayMedium: TextStyle(color: creamWhite),
          displaySmall: TextStyle(color: creamWhite),
          headlineLarge: TextStyle(color: creamWhite),
          headlineMedium: TextStyle(color: creamWhite),
          headlineSmall: TextStyle(color: creamWhite),
          titleLarge: TextStyle(color: creamWhite),
          titleMedium: TextStyle(color: creamWhite),
          titleSmall: TextStyle(color: creamWhite),
          bodyLarge: TextStyle(color: creamWhite),
          bodyMedium: TextStyle(color: creamWhite),
          bodySmall: TextStyle(color: creamWhite),
          labelLarge: TextStyle(color: creamWhite),
          labelMedium: TextStyle(color: creamWhite),
          labelSmall: TextStyle(color: creamWhite),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bloodRed,
        contentTextStyle: GoogleFonts.cinzel(color: creamWhite),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: gold, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bloodRed,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bloodRed,
        foregroundColor: creamWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cinzelDecorative(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: gold,
        ),
        iconTheme: const IconThemeData(color: gold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bloodRed,
          foregroundColor: gold,
          textStyle: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: gold, width: 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold, width: 2),
          textStyle: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: midnightNavy,
        surfaceTintColor: Colors.transparent,
        textStyle: GoogleFonts.cinzel(color: creamWhite),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bloodRed,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: parchmentOverlay,
    );
  }
}
