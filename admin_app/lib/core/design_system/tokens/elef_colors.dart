import 'package:flutter/material.dart';

/// ELEF Design System — Palette Chromatique Centralisée
/// Fournit les couleurs sémantiques, surfaces, bordures et accents disciplinaires.
class ElefColors {
  ElefColors._();

  // --- Surfaces & Fonds (Dark Mode par défaut pour l'admin et studio) ---
  static const Color background = Color(0xFF0A0F1D);       // Fond très profond
  static const Color surfaceDark = Color(0xFF111827);       // Slate 900
  static const Color surfaceCard = Color(0xFF1E293B);       // Slate 800
  static const Color surfaceElevated = Color(0xFF27354A);   // Slate 750
  static const Color surfaceHover = Color(0xFF334155);      // Slate 700
  static const Color surfaceOverlay = Color(0xCC0F172A);    // 80% opacity

  // --- Bordures & Séparateurs ---
  static const Color borderSubtle = Color(0xFF1E293B);
  static const Color borderMedium = Color(0xFF334155);
  static const Color borderActive = Color(0xFF475569);
  static const Color borderHighlight = Color(0xFF38BDF8);

  // --- Typographie & Textes ---
  static const Color textPrimary = Color(0xFFF8FAFC);     // Blanc cassé 98%
  static const Color textSecondary = Color(0xFFCBD5E1);   // Gris clair 80%
  static const Color textMuted = Color(0xFF94A3B8);       // Gris neutre 60%
  static const Color textDisabled = Color(0xFF64748B);    // Gris sombre 40%

  // --- Couleurs d'Action Principales ---
  static const Color primary = Color(0xFF0EA5E9);         // Sky 500
  static const Color primaryHover = Color(0xFF38BDF8);    // Sky 400
  static const Color primaryPressed = Color(0xFF0284C7);  // Sky 600
  static const Color primaryGlow = Color(0x330EA5E9);     // Glow 20%

  static const Color secondary = Color(0xFF6366F1);       // Indigo 500
  static const Color secondaryHover = Color(0xFF818CF8);  // Indigo 400

  // --- États Sémantiques ---
  static const Color success = Color(0xFF10B981);         // Emerald 500
  static const Color successBg = Color(0x1F10B981);       // 12% opacity
  static const Color successBorder = Color(0x4D10B981);   // 30% opacity

  static const Color warning = Color(0xFFF59E0B);         // Amber 500
  static const Color warningBg = Color(0x1FF59E0B);       // 12% opacity
  static const Color warningBorder = Color(0x4DF59E0B);   // 30% opacity

  static const Color danger = Color(0xFFF43F5E);          // Rose 500
  static const Color dangerBg = Color(0x1FF43F5E);        // 12% opacity
  static const Color dangerBorder = Color(0x4DF43F5E);    // 30% opacity

  static const Color info = Color(0xFF06B6D4);            // Cyan 500
  static const Color infoBg = Color(0x1F06B6D4);          // 12% opacity
  static const Color infoBorder = Color(0x4D06B6D4);      // 30% opacity

  // --- Accents Disciplinaires Spécifiques (ELEF Learning Engine) ---
  static const Color disciplineMath = Color(0xFF06B6D4);        // Cyan 500 (Mathématiques)
  static const Color disciplinePhysics = Color(0xFFF59E0B);     // Ambre (Physique)
  static const Color disciplineChemistry = Color(0xFF10B981);   // Émeraude (Chimie)
  static const Color disciplineBiology = Color(0xFF84CC16);     // Lime (SVT / Biologie)
  static const Color disciplineComputer = Color(0xFF3B82F6);    // Bleu (Informatique & Code)
  static const Color disciplineLiterature = Color(0xFFA855F7);  // Violet (Français / Littérature)
  static const Color disciplinePhilosophy = Color(0xFFEC4899);  // Rose (Philosophie)
  static const Color disciplineHistory = Color(0xFFD97706);     // Ambre foncé (Histoire / Géo)
  static const Color disciplineTechnical = Color(0xFFF97316);   // Orange vif (Mécanique / Électronique)
  static const Color disciplineCommercial = Color(0xFF14B8A6);  // Teal (Économie / Gestion)
  static const Color disciplineIndustrial = Color(0xFF64748B);  // Slate (Génie civil / Métiers industriels)

  /// Retourne la couleur maîtresse d'une discipline donnée
  static Color forSubject(String? subjectName) {
    if (subjectName == null) return primary;
    final lower = subjectName.toLowerCase();
    if (lower.contains('math')) return disciplineMath;
    if (lower.contains('physiq') || lower.contains('optiq')) return disciplinePhysics;
    if (lower.contains('chim')) return disciplineChemistry;
    if (lower.contains('svt') || lower.contains('bio')) return disciplineBiology;
    if (lower.contains('info') || lower.contains('code') || lower.contains('prog')) return disciplineComputer;
    if (lower.contains('litt') || lower.contains('fran')) return disciplineLiterature;
    if (lower.contains('philo')) return disciplinePhilosophy;
    if (lower.contains('hist') || lower.contains('géo')) return disciplineHistory;
    if (lower.contains('élec') || lower.contains('méc') || lower.contains('tech')) return disciplineTechnical;
    if (lower.contains('éco') || lower.contains('compt') || lower.contains('commerc')) return disciplineCommercial;
    if (lower.contains('indus') || lower.contains('génie')) return disciplineIndustrial;
    return primary;
  }
}
