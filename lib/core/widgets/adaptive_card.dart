import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Enveloppe une section de contenu dans une carte bordée (fond, coins arrondis, bordure) —
/// mais seulement au-delà du seuil mobile. En dessous, elle rend juste le contenu directement
/// sur le fond de page, sans cadre.
///
/// Raison d'être : desktop juxtapose souvent plusieurs cartes côte à côte (une grille, deux
/// panneaux), où une bordure aide vraiment à distinguer les sections. Une fois empilées en
/// pleine largeur sur mobile, ces mêmes cartes n'entourent plus qu'une section déjà seule sur
/// un écran déjà borné — la bordure ne sépare plus rien, elle s'ajoute juste en plus (retour
/// utilisateur réel très explicite, "trop de box et d'élément dans un même interface",
/// 2026-09-01 — même principe que WhatsApp mobile vs desktop : une structure différente, pas
/// la même repliée).
///
/// N'utilisez PAS ce widget pour une carte dans une liste (un compte, un exercice, une session)
/// — ces cartes-là restent justifiées sur mobile, ce sont des entités distinctes répétées, pas
/// une simple section de page.
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double mobileBreakpoint;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.mobileBreakpoint = 700,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < mobileBreakpoint;
    if (isMobile) return child;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: child,
    );
  }
}
