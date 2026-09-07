import 'package:flutter/material.dart';

/// ELEF Design System — Rayons de Courbure Centralisés
class ElefRadius {
  ElefRadius._();

  static const double rawXs = 4.0;
  static const double rawSm = 8.0;
  static const double rawMd = 12.0;
  static const double rawLg = 16.0;
  static const double rawXl = 24.0;
  static const double rawFull = 999.0;

  // BorderRadius prêts à l'emploi
  static final BorderRadius xs = BorderRadius.circular(rawXs);
  static final BorderRadius sm = BorderRadius.circular(rawSm);
  static final BorderRadius md = BorderRadius.circular(rawMd);
  static final BorderRadius lg = BorderRadius.circular(rawLg);
  static final BorderRadius xl = BorderRadius.circular(rawXl);
  static final BorderRadius full = BorderRadius.circular(rawFull);
}
