import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_typography.dart';

enum ElefCalloutType {
  definition,
  theorem,
  formula,
  method,
  example,
  warning,
  tip,
  remark,
}

/// ELEF Design System — Encadré Pédagogique Haute Fidélité
/// Remplace les boîtes lourdes et encombrantes par des blocs typographiques aérés,
/// bordés d'un liseré disciplinaire et d'une icône explicite.
class ElefCallout extends StatelessWidget {
  final ElefCalloutType type;
  final String? title;
  final String content;
  final List<String> formulas;
  final Widget? trailing;

  const ElefCallout({
    super.key,
    required this.type,
    this.title,
    required this.content,
    this.formulas = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    Color accent;
    Color bg;
    IconData icon;
    String defaultTitle;

    switch (type) {
      case ElefCalloutType.definition:
        accent = ElefColors.disciplineMath;
        bg = ElefColors.disciplineMath.withAlpha(18);
        icon = Icons.menu_book_rounded;
        defaultTitle = 'Définition';
        break;
      case ElefCalloutType.theorem:
        accent = ElefColors.secondary;
        bg = ElefColors.secondary.withAlpha(18);
        icon = Icons.verified_rounded;
        defaultTitle = 'Théorème & Propriété';
        break;
      case ElefCalloutType.formula:
        accent = ElefColors.primary;
        bg = ElefColors.primary.withAlpha(18);
        icon = Icons.functions_rounded;
        defaultTitle = 'Formule Fondamentale';
        break;
      case ElefCalloutType.method:
        accent = ElefColors.disciplinePhysics;
        bg = ElefColors.disciplinePhysics.withAlpha(18);
        icon = Icons.lightbulb_outline_rounded;
        defaultTitle = 'Méthode & Savoir-faire';
        break;
      case ElefCalloutType.example:
        accent = ElefColors.disciplineChemistry;
        bg = ElefColors.disciplineChemistry.withAlpha(18);
        icon = Icons.auto_awesome_rounded;
        defaultTitle = 'Exemple d\'Application';
        break;
      case ElefCalloutType.warning:
        accent = ElefColors.danger;
        bg = ElefColors.danger.withAlpha(18);
        icon = Icons.warning_amber_rounded;
        defaultTitle = 'Piège d\'Examen Classique';
        break;
      case ElefCalloutType.tip:
        accent = ElefColors.warning;
        bg = ElefColors.warning.withAlpha(18);
        icon = Icons.tips_and_updates_rounded;
        defaultTitle = 'Conseil & Astuce du Correcteur';
        break;
      case ElefCalloutType.remark:
        accent = ElefColors.textMuted;
        bg = ElefColors.surfaceDark;
        icon = Icons.info_outline_rounded;
        defaultTitle = 'À Remarquer';
        break;
    }

    final effectiveTitle = title?.isNotEmpty == true ? title! : defaultTitle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ElefRadius.md,
        border: Border(
          left: BorderSide(color: accent, width: 3.5),
          top: BorderSide(color: accent.withAlpha(40), width: 1),
          right: BorderSide(color: accent.withAlpha(40), width: 1),
          bottom: BorderSide(color: accent.withAlpha(40), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  effectiveTitle,
                  style: ElefTypography.titleSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: ElefTypography.bodyMedium.copyWith(
                color: ElefColors.textPrimary,
                height: 1.55,
              ),
            ),
          ],
          if (formulas.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...formulas.map((f) => _buildFormulaBox(f, accent)),
          ],
        ],
      ),
    );
  }

  Widget _buildFormulaBox(String latex, Color accent) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ElefColors.surfaceDark,
        borderRadius: ElefRadius.sm,
        border: Border.all(color: accent.withAlpha(60), width: 0.8),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            latex,
            mathStyle: MathStyle.display,
            textStyle: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            onErrorFallback: (err) => Text(
              latex,
              style: ElefTypography.code.copyWith(color: ElefColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
