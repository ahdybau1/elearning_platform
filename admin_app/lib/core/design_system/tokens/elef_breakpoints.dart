import 'package:flutter/material.dart';

/// ELEF Design System — Breakpoints & Responsive Helpers
class ElefBreakpoints {
  ElefBreakpoints._();

  static const double mobileMax = 640.0;
  static const double tabletMax = 1024.0;
  static const double desktopMax = 1440.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletMax && width < desktopMax;
  }

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMax;

  /// Largeur maximale de lecture pour le contenu pédagogique (optimise le confort visuel)
  static const double maxContentWidth = 1200.0;
  static const double maxReadingWidth = 780.0;
}
