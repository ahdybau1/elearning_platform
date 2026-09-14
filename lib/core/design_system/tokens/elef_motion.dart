import 'package:flutter/material.dart';

/// ELEF Design System — Animations & Transitions Centralisées
class ElefMotion {
  ElefMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration smooth = Duration(milliseconds: 400);
  static const Duration long = Duration(milliseconds: 600);

  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;
}
