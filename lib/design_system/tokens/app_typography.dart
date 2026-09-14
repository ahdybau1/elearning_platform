import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de typographie unifiés pour EDLEARN.
///
/// Titres en [Outfit] (chaleureux, géométrique et lisible),
/// Textes et contenus de lecture en [Inter] (clarté maximale).
class AppTypography {
  AppTypography._();

  static TextStyle displayLarge({required Color color}) => GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: color,
        height: 1.2,
      );

  static TextStyle displayMedium({required Color color}) => GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: color,
        height: 1.25,
      );

  static TextStyle titleLarge({required Color color}) => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      );

  static TextStyle titleMedium({required Color color}) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.35,
      );

  static TextStyle bodyLarge({required Color color, double height = 1.6}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: color,
        height: height,
      );

  static TextStyle bodyMedium({required Color color, double height = 1.45}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: color,
        height: height,
      );

  static TextStyle bodySmall({required Color color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: color,
        height: 1.3,
      );

  static TextStyle label({required Color color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.2,
      );
}
