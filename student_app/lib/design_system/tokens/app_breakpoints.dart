import 'package:flutter/material.dart';

/// Définition et utilitaires de breakpoints pour EDLEARN.
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileCompactMax = 359.0;
  static const double mobileStandardMax = 599.0;
  static const double tabletPortraitMax = 899.0;
  static const double tabletLandscapeMax = 1199.0;

  static bool isCompactMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= mobileCompactMax;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= mobileStandardMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > mobileStandardMax && w <= tabletLandscapeMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width > tabletLandscapeMax;

  /// Largeur maximale de lecture optimale pour les cours (évite la fatigue visuelle).
  static const double maxReadingWidth = 760.0;
  static const double maxDashboardWidth = 1080.0;
}
