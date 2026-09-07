import 'package:flutter/material.dart';

/// Tokens de couleurs centralisés pour EDLEARN Student.
///
/// Ces constantes et nuances sont résolues via le thème actif ([StudentColors]),
/// assurant la conformité avec le mode sombre, le mode clair et le contraste élevé.
class AppColors {
  AppColors._();

  // Surfaces sombres (par défaut pour l'application)
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkCard = Color(0xFF1B243B);
  static const Color darkBorder = Color(0xFF2B3754);

  // Surfaces claires
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Surfaces Contraste Élevé
  static const Color hcDarkBackground = Color(0xFF000000);
  static const Color hcDarkBorder = Color(0xFFE5E7EB);
  static const Color hcLightBackground = Color(0xFFFFFFFF);
  static const Color hcLightBorder = Color(0xFF000000);

  // Accents sémantiques pédagogiques
  static const Color primaryCyan = Color(0xFF38BDF8); // Action primaire & IA
  static const Color cyanPrimary = Color(0xFF38BDF8);
  static const Color cyanAccent = Color(0xFF06B6D4);  // Tuteur Numérique
  static const Color indigoAccent = Color(0xFF6366F1);// Définition formelle
  static const Color emeraldSuccess = Color(0xFF10B981);// Réussite / Validé
  static const Color tealSuccess = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);  // Indices / Attention
  static const Color amberHighlight = Color(0xFFF59E0B);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color roseError = Color(0xFFF43F5E);    // Erreur / Piège d'examen
  static const Color purpleExample = Color(0xFFA855F7);// Exemple / Pratique
  static const Color goldPremium = Color(0xFFF59E0B);  // Badge formule abonné

  // Textes
  static const Color textLightPrimary = Color(0xFFFFFFFF);
  static const Color textLightSecondary = Color(0xFF94A3B8);
  static const Color textLightMuted = Color(0xFF64748B);

  static const Color textDarkPrimary = Color(0xFF0F172A);
  static const Color textDarkSecondary = Color(0xFF475569);
  static const Color textDarkMuted = Color(0xFF94A3B8);

  // Gradients signatures
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
