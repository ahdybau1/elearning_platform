import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_typography.dart';
import '../components/elef_badge.dart';

/// Section structurée d'une Fiche de Synthèse Visuelle
class ElefSummarySectionData {
  final String title;
  final String? formulaLatex;
  final String? explanation;
  final List<String> bulletPoints;
  final String? tip;
  final Map<String, String>? comparativeColumns; // e.g. {'Arithmétique': '...', 'Géométrique': '...'}

  const ElefSummarySectionData({
    required this.title,
    this.formulaLatex,
    this.explanation,
    this.bulletPoints = const [],
    this.tip,
    this.comparativeColumns,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    if (formulaLatex != null) 'formula_latex': formulaLatex,
    if (explanation != null) 'explanation': explanation,
    'bullet_points': bulletPoints,
    if (tip != null) 'tip': tip,
    if (comparativeColumns != null) 'comparative_columns': comparativeColumns,
  };

  factory ElefSummarySectionData.fromJson(Map<String, dynamic> json) {
    return ElefSummarySectionData(
      title: json['title'] as String? ?? 'Section',
      formulaLatex: json['formula_latex'] as String?,
      explanation: json['explanation'] as String?,
      bulletPoints: ((json['bullet_points'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      tip: json['tip'] as String?,
      comparativeColumns: json['comparative_columns'] != null
          ? Map<String, String>.from(json['comparative_columns'] as Map)
          : null,
    );
  }
}

/// ELEF Design System — Composant Fiche de Synthèse Visuelle Haute Fidélité
/// Permet de reproduire traits pour traits les fiches mémo de référence (ex: Suites Numériques)
/// avec mise en page éditoriale, colonnes comparatives, formules LaTeX et théorèmes majeurs.
class ElefSummarySheetCard extends StatelessWidget {
  final String title;
  final String subject;
  final String level;
  final String? officialSource;
  final List<ElefSummarySectionData> sections;
  final List<Map<String, dynamic>>? columns;
  final String? keyFormula;
  final List<String> bulletPoints;
  final String? examTrap;

  const ElefSummarySheetCard({
    super.key,
    required this.title,
    required this.subject,
    this.level = 'Terminale C, D & TI',
    this.officialSource = 'Conforme Programme Officiel MINESEC / Bac',
    this.sections = const [],
    this.columns,
    this.keyFormula,
    this.bulletPoints = const [],
    this.examTrap,
  });

  @override
  Widget build(BuildContext context) {
    final disciplineColor = ElefColors.forSubject(subject);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: ElefRadius.xl,
        border: Border.all(color: disciplineColor.withAlpha(90), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de la Fiche de Référence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: disciplineColor.withAlpha(25),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ElefRadius.rawXl - 1),
                topRight: Radius.circular(ElefRadius.rawXl - 1),
              ),
              border: Border(
                bottom: BorderSide(color: disciplineColor.withAlpha(60), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: disciplineColor.withAlpha(40),
                    borderRadius: ElefRadius.md,
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: disciplineColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ElefTypography.heading2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          ElefBadge(label: subject, color: disciplineColor, tone: ElefBadgeTone.subtle),
                          const SizedBox(width: 8),
                          ElefBadge(label: level, color: ElefColors.textMuted, tone: ElefBadgeTone.outline),
                          const SizedBox(width: 8),
                          Text(
                            officialSource ?? '',
                            style: ElefTypography.caption.copyWith(color: ElefColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Corps des Sections de la Fiche
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (columns != null && columns!.isNotEmpty) ...[
                  _buildDirectColumnsLayout(disciplineColor),
                ] else ...[
                  ...sections.map((sec) => _buildSection(sec, disciplineColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectColumnsLayout(Color disciplineColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonnes côte à côte
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final colWidgets = columns!.map((col) {
              final colTitle = col['title'] as String? ?? 'Colonne';
              final badgeText = col['badge'] as String?;
              final colColor = col['color'] != null ? Color(col['color'] as int) : disciplineColor;
              final items = (col['items'] as List?) ?? [];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF11192A),
                  borderRadius: ElefRadius.lg,
                  border: Border.all(color: colColor.withAlpha(80), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            colTitle,
                            style: ElefTypography.titleMedium.copyWith(
                              color: colColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badgeText != null)
                          ElefBadge(
                            label: badgeText,
                            color: colColor,
                            tone: ElefBadgeTone.subtle,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...items.map((item) {
                      final itemMap = Map<String, dynamic>.from(item as Map);
                      final label = itemMap['label'] as String? ?? '';
                      final formula = itemMap['formula'] as String? ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D18),
                          borderRadius: ElefRadius.md,
                          border: Border.all(color: ElefColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (label.isNotEmpty) ...[
                              Text(
                                label,
                                style: ElefTypography.caption.copyWith(
                                  color: ElefColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (formula.isNotEmpty)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Math.tex(
                                  formula,
                                  mathStyle: MathStyle.display,
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                  onErrorFallback: (err) => Text(
                                    formula,
                                    style: ElefTypography.code,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }).toList();

            if (isNarrow) {
              return Column(
                children: colWidgets
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: w,
                        ))
                    .toList(),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: colWidgets
                  .map((w) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: w,
                        ),
                      ))
                  .toList(),
            );
          },
        ),

        // Formule centrale / règle générale
        if (keyFormula != null && keyFormula!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1020),
              borderRadius: ElefRadius.lg,
              border: Border.all(color: disciplineColor.withAlpha(90), width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  'Formule / Propriété Générale',
                  style: ElefTypography.caption.copyWith(
                    color: disciplineColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    keyFormula!,
                    mathStyle: MathStyle.display,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    onErrorFallback: (err) => Text(keyFormula!, style: ElefTypography.code),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Puces d'analyse
        if (bulletPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ElefColors.surfaceCard,
              borderRadius: ElefRadius.md,
              border: Border.all(color: ElefColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: disciplineColor),
                    const SizedBox(width: 8),
                    Text(
                      'Points Clés & Astuces Méthodologiques',
                      style: ElefTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...bulletPoints.map((pt) => Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 5, color: disciplineColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pt,
                              style: ElefTypography.bodySmall.copyWith(
                                color: ElefColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],

        // Piège d'examen
        if (examTrap != null && examTrap!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ElefColors.dangerBg,
              borderRadius: ElefRadius.md,
              border: Border.all(color: ElefColors.dangerBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: ElefColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attention : Piège Classique d\'Examen',
                        style: ElefTypography.labelMedium.copyWith(
                          color: ElefColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        examTrap!,
                        style: ElefTypography.bodySmall.copyWith(
                          color: ElefColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(ElefSummarySectionData sec, Color disciplineColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderMedium, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de Section
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: disciplineColor,
                  borderRadius: ElefRadius.xs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sec.title,
                  style: ElefTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Colonnes Comparatives (si existantes, ex: Arithmétique vs Géométrique)
          if (sec.comparativeColumns != null && sec.comparativeColumns!.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final items = sec.comparativeColumns!.entries.toList();
                if (isNarrow) {
                  return Column(
                    children: items.map((e) => _comparativeColumnCard(e.key, e.value, disciplineColor)).toList(),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map((e) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: _comparativeColumnCard(e.key, e.value, disciplineColor),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],

          // Formule LaTeX centrale de la section
          if (sec.formulaLatex != null && sec.formulaLatex!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF090D18),
                borderRadius: ElefRadius.md,
                border: Border.all(color: disciplineColor.withAlpha(50)),
              ),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    sec.formulaLatex!,
                    mathStyle: MathStyle.display,
                    textStyle: const TextStyle(fontSize: 16.5, color: Colors.white),
                    onErrorFallback: (err) => Text(
                      sec.formulaLatex!,
                      style: ElefTypography.code,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Explication & Puces d'apprentissage
          if (sec.explanation != null && sec.explanation!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              sec.explanation!,
              style: ElefTypography.bodyMedium.copyWith(color: ElefColors.textSecondary),
            ),
          ],

          if (sec.bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...sec.bulletPoints.map((pt) => Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 5, color: disciplineColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pt,
                          style: ElefTypography.bodySmall.copyWith(
                            color: ElefColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Encadré Conseil / Astuce
          if (sec.tip != null && sec.tip!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ElefColors.warningBg,
                borderRadius: ElefRadius.md,
                border: Border.all(color: ElefColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: ElefColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sec.tip!,
                      style: ElefTypography.bodySmall.copyWith(
                        color: ElefColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparativeColumnCard(String title, String content, Color disciplineColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: ElefRadius.md,
        border: Border.all(color: ElefColors.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ElefTypography.titleSmall.copyWith(
              color: disciplineColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: ElefTypography.bodySmall.copyWith(color: ElefColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
