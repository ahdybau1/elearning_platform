import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primarySurface = Color(0xFF1E293B); // Slate 800
  static const Color primaryBorder = Color(0xFF334155); // Slate 700
  static const Color accentBlue = Color(0xFF3B82F6); // Blue 500
  static const Color accentIndigo = Color(0xFF6366F1); // Indigo 500
  static const Color accentEmerald = Color(0xFF10B981); // Emerald 500
  static const Color accentAmber = Color(0xFFF59E0B); // Amber 500
  static const Color accentRose = Color(0xFFF43F5E); // Rose 500
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan 500

  // Neutral Light Colors
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Convenient Aliases for Dark Theme
  static const Color cardBackground = primarySurface;
  static const Color surfaceDark = primarySurface;
  static const Color borderColor = primaryBorder;
  static const Color textSecondary = textMuted;
  static const Color accentPurple = accentIndigo;

  // Dark Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentEmerald,
        surface: primarySurface,
        error: accentRose,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: primarySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: primaryBorder, width: 1),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              color: Colors.white,
            ),
            displayMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
            titleLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.white,
            ),
            titleMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Colors.white,
            ),
            bodyLarge: GoogleFonts.inter(fontSize: 15, color: Colors.white70),
            bodyMedium: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
          ),
      dividerTheme: const DividerThemeData(color: primaryBorder, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Light Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: accentBlue,
        secondary: accentEmerald,
        surface: surfaceLight,
        error: accentRose,
        onPrimary: Colors.white,
        onSurface: textDark,
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              color: textDark,
            ),
            displayMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: textDark,
            ),
            titleLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: textDark,
            ),
            titleMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: textDark,
            ),
            bodyLarge: GoogleFonts.inter(fontSize: 15, color: textDark),
            bodyMedium: GoogleFonts.inter(fontSize: 13, color: textMuted),
          ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
