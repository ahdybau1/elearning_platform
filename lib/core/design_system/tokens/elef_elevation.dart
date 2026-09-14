import 'package:flutter/material.dart';

/// ELEF Design System — Élévations et Ombres Centralisées
class ElefElevation {
  ElefElevation._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x28000000),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> dialog = [
    BoxShadow(
      color: Color(0x52000000),
      offset: Offset(0, 12),
      blurRadius: 32,
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> glowPrimary = [
    BoxShadow(
      color: Color(0x330EA5E9),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];
}
