import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'elef_colors.dart';

/// ELEF Design System — Typographie Centralisée
/// Règle la hiérarchie visuelle pour les écrans de création de cours,
/// les formules scientifiques, les fiches mémo et les interfaces de travail.
class ElefTypography {
  ElefTypography._();

  // --- Display & Titres Majeurs (Outfit) ---
  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: ElefColors.textPrimary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static TextStyle displayMedium = GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: ElefColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static TextStyle heading1 = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: ElefColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle heading2 = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ElefColors.textPrimary,
  );

  static TextStyle heading3 = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ElefColors.textPrimary,
  );

  // --- Titres de Blocs & Cartes Pédagogiques ---
  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ElefColors.textPrimary,
  );

  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: ElefColors.textPrimary,
  );

  // --- Corps de Texte (Inter - Confort de lecture optimal) ---
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: ElefColors.textSecondary,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: ElefColors.textSecondary,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: ElefColors.textMuted,
    height: 1.4,
  );

  // --- Légendes, Badges & Métadonnées ---
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: ElefColors.textPrimary,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: ElefColors.textPrimary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: ElefColors.textMuted,
    letterSpacing: 0.2,
  );

  static TextStyle badge = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // --- Code & Formules Monospace (Fira Code) ---
  static TextStyle code = GoogleFonts.firaCode(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: ElefColors.primaryHover,
    height: 1.4,
  );
}
