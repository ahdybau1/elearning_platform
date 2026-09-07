import 'package:flutter/material.dart';

/// Échelle d'espacements stricte (grille de 4/8 px) pour EDLEARN.
class AppSpacing {
  AppSpacing._();

  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0; // Hauteur tactile minimum WCAG

  // EdgeInsets raccourcis
  static const EdgeInsets pagePaddingMobile = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets pagePaddingStandard = EdgeInsets.all(20.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingDense = EdgeInsets.all(12.0);
  static const EdgeInsets modalPadding = EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0);
}
