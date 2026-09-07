import 'package:flutter/material.dart';

/// Rayons de courbure normalisés pour EDLEARN.
class AppRadius {
  AppRadius._();

  static const double r4 = 4.0;
  static const double r6 = 6.0;   // Badges discrets
  static const double r10 = 10.0;
  static const double r12 = 12.0; // Boutons d'action, options QCM
  static const double r16 = 16.0; // Cartes de chapitres, conteneurs de leçons
  static const double r20 = 20.0; // Cartes héroïques
  static const double r24 = 24.0; // Modales, Bottom Sheets
  static const double rFull = 999.0; // Pastilles, avatars

  // Alias sémantiques
  static const double badge = r6;
  static const double button = r12;
  static const double card = r16;
  static const double modal = r24;

  static BorderRadius get radiusSmall => BorderRadius.circular(r6);
  static BorderRadius get radiusMedium => BorderRadius.circular(r12);
  static BorderRadius get radiusLarge => BorderRadius.circular(r16);
  static BorderRadius get radiusXLarge => BorderRadius.circular(r24);
  static BorderRadius get radiusFull => BorderRadius.circular(rFull);
}
