import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentTheme {
  // Palette Vibrante & Sombre Moderne (Gradients & Glassmorphism)
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF131B2E);
  static const Color cardDark = Color(0xFF1B243B);
  static const Color borderDark = Color(0xFF2B3754);

  // Accents Colorés
  static const Color accentPrimary = Color(0xFF38BDF8); // Cyan Lumineux
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan
  static const Color accentIndigo = Color(0xFF6366F1); // Indigo
  static const Color accentEmerald = Color(0xFF10B981); // Émeraude Succès
  static const Color accentAmber = Color(0xFFF59E0B); // Ambre Avertissement
  static const Color accentRose = Color(0xFFF43F5E); // Rose
  static const Color accentPurple = Color(0xFFA855F7); // Violet

  // Typographie & Textes
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients Signature
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: accentPrimary,
        secondary: accentEmerald,
        surface: surfaceDark,
        error: accentRose,
        onPrimary: Colors.black,
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 30,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: textSecondary,
        ),
      ),
    );
  }
}
