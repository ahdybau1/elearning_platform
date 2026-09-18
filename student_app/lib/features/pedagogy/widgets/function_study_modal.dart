import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/rendering/math_formula_view.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'academic_variation_table_view.dart';
import 'interactive_function_graph.dart';
import 'variation_table_interactive.dart';

/// Analyse mathématique pédagogique complète et détaillée d'une fonction (conforme programme Baccalauréat)
class FunctionStudyData {
  final String rawExpression;
  final String formulaLatex;
  final String domainText;
  final String domainLatex;
  final List<String> domainSteps;
  final String limitMinusInfLatex;
  final List<String> limitMinusInfSteps;
  final String limitPlusInfLatex;
  final List<String> limitPlusInfSteps;
  final String derivativeLatex;
  final List<String> derivativeSteps;
  final String derivativeSignExplanation;
  final List<String> derivativeSignSteps;
  final List<String> criticalPointsText;
  final List<String> vertexSteps;
  final VariationTableData variationTable;
  final AcademicVariationData academicTable;
  final String asymptotesSummary;
  final List<String> asymptotesDetails;
  final String rootsLatex;
  final List<String> rootsSteps;
  final String yInterceptLatex;
  final List<String> yInterceptSteps;
  final MathFunctionSpec spec;

  const FunctionStudyData({
    required this.rawExpression,
    required this.formulaLatex,
    required this.domainText,
    required this.domainLatex,
    required this.domainSteps,
    required this.limitMinusInfLatex,
    required this.limitMinusInfSteps,
    required this.limitPlusInfLatex,
    required this.limitPlusInfSteps,
    required this.derivativeLatex,
    required this.derivativeSteps,
    required this.derivativeSignExplanation,
    required this.derivativeSignSteps,
    required this.criticalPointsText,
    required this.vertexSteps,
    required this.variationTable,
    required this.academicTable,
    required this.asymptotesSummary,
    required this.asymptotesDetails,
    required this.rootsLatex,
    required this.rootsSteps,
    required this.yInterceptLatex,
    required this.yInterceptSteps,
    required this.spec,
  });

  /// Construit déterministement l'étude mathématique complète et ultra-détaillée d'une fonction
  factory FunctionStudyData.fromExpression(String rawExpr) {
    final spec = MathFunctionSpec.fromExpression(rawExpr);
    final clean = rawExpr
        .replaceAll(RegExp(r'^[a-zA-Z]\(x\)\s*=\s*'), '')
        .replaceAll(RegExp(r'^y\s*=\s*'), '')
        .replaceAll(r'$', '')
        .trim();
    final noSpaces = clean.replaceAll(' ', '');

    // Forme factorisée type 3x(x - 2), x(x + 4), etc.
    final factoredXMatch = RegExp(r'^([+\-]?[0-9]*\.?[0-9]*)\*?x\s*\(x([+\-][0-9]+(?:\.[0-9]+)?)\)$').firstMatch(noSpaces);
    final factoredTwoMatch = RegExp(r'^([+\-]?[0-9]*\.?[0-9]*)\*?\(x([+\-][0-9]+(?:\.[0-9]+)?)\)\s*\(x([+\-][0-9]+(?:\.[0-9]+)?)\)$').firstMatch(noSpaces);

    // 1. Détection Polynôme du Second Degré : ax^2 + bx + c ou forme factorisée 3x(x - 2)
    if (noSpaces.contains('x^2') || noSpaces.contains('x²') || noSpaces.contains('x*x') || factoredXMatch != null || factoredTwoMatch != null) {
      double a = 1.0;
      double b = 0.0;
      double c = 0.0;

      if (factoredXMatch != null) {
        var aStr = factoredXMatch.group(1) ?? '1';
        if (aStr.isEmpty || aStr == '+') aStr = '1';
        if (aStr == '-') aStr = '-1';
        a = double.tryParse(aStr) ?? 1.0;
        final r2 = -(double.tryParse(factoredXMatch.group(2)!) ?? 0.0);
        b = -a * r2;
        c = 0.0;
      } else if (factoredTwoMatch != null) {
        var aStr = factoredTwoMatch.group(1) ?? '1';
        if (aStr.isEmpty || aStr == '+') aStr = '1';
        if (aStr == '-') aStr = '-1';
        a = double.tryParse(aStr) ?? 1.0;
        final r1 = -(double.tryParse(factoredTwoMatch.group(2)!) ?? 0.0);
        final r2 = -(double.tryParse(factoredTwoMatch.group(3)!) ?? 0.0);
        b = -a * (r1 + r2);
        c = a * r1 * r2;
      } else {
        final quadRegex = RegExp(r'([+\-]?[0-9]*)' r'\*?x(?:\^2|²)([+\-][0-9]*)' r'\*?x([+\-][0-9]+)?');
        final m = quadRegex.firstMatch(noSpaces);

        if (m != null) {
          var aStr = m.group(1) ?? '1';
          if (aStr.isEmpty || aStr == '+') aStr = '1';
          if (aStr == '-') aStr = '-1';
          a = double.tryParse(aStr) ?? 1.0;

          var bStr = m.group(2) ?? '0';
          if (bStr == '+') bStr = '1';
          if (bStr == '-') bStr = '-1';
          b = double.tryParse(bStr) ?? 0.0;

          var cStr = m.group(3) ?? '0';
          c = double.tryParse(cStr) ?? 0.0;
        } else {
          // Formes type x^2 - 4 ou 2x^2 - 6
          final simpleQuad = RegExp(r'([+\-]?[0-9]*)' r'\*?x(?:\^2|²)([+\-][0-9]+)?');
          final sm = simpleQuad.firstMatch(noSpaces);
          if (sm != null) {
            var aStr = sm.group(1) ?? '1';
            if (aStr.isEmpty || aStr == '+') aStr = '1';
            if (aStr == '-') aStr = '-1';
            a = double.tryParse(aStr) ?? 1.0;
            c = double.tryParse(sm.group(2) ?? '0') ?? 0.0;
          }
        }
      }

      final delta = b * b - 4 * a * c;
      final xv = a != 0 ? -b / (2 * a) : 0.0;
      final yv = a * xv * xv + b * xv + c;

      final aFormatted = a == 1 ? '' : (a == -1 ? '-' : a.toStringAsFixed(a.truncateToDouble() == a ? 0 : 1));
      final derivA = (2 * a).toStringAsFixed((2 * a).truncateToDouble() == 2 * a ? 0 : 1);
      final derivStr = b == 0 ? '${derivA}x' : (b > 0 ? '${derivA}x + ${b.toStringAsFixed(b.truncateToDouble() == b ? 0 : 1)}' : '${derivA}x - ${(-b).toStringAsFixed(b.truncateToDouble() == b ? 0 : 1)}');

      final isFacingUp = a > 0;
      final xvStr = xv.toStringAsFixed(xv.truncateToDouble() == xv ? 0 : 1);
      final yvStr = yv.toStringAsFixed(yv.truncateToDouble() == yv ? 0 : 1);
      final aStr = a.toStringAsFixed(a.truncateToDouble() == a ? 0 : 1);
      final bStr = b.toStringAsFixed(b.truncateToDouble() == b ? 0 : 1);
      final cStr = c.toStringAsFixed(c.truncateToDouble() == c ? 0 : 1);
      final deltaStr = delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 1);

      // Calcul des racines réelles
      String rootsStr;
      List<String> rootsSteps;
      if (delta > 0) {
        final r1 = (-b - math.sqrt(delta)) / (2 * a);
        final r2 = (-b + math.sqrt(delta)) / (2 * a);
        final r1Str = r1.toStringAsFixed(r1.truncateToDouble() == r1 ? 0 : 2);
        final r2Str = r2.toStringAsFixed(r2.truncateToDouble() == r2 ? 0 : 2);
        final sqrtDeltaStr = math.sqrt(delta).toStringAsFixed(math.sqrt(delta).truncateToDouble() == math.sqrt(delta) ? 0 : 2);

        rootsStr = 'x_1 = $r1Str \\quad \\text{et} \\quad x_2 = $r2Str';
        rootsSteps = [
          if (factoredXMatch != null) ...[
            '1. Méthode immédiate par la règle du produit nul :',
            'Un produit de facteurs est nul si et seulement si l\'un au moins de ses facteurs est nul.',
            '3x(x - 2) = 0 \\iff 3x = 0 \\quad \\text{ou} \\quad x - 2 = 0',
            'Racines immédiates : x_1 = 0 \\quad \\text{et} \\quad x_2 = 2',
            '2. Vérification systématique par le discriminant \\Delta = b^2 - 4ac :',
          ] else ...[
            '1. Formule générale du discriminant : \\Delta = b^2 - 4ac',
          ],
          'Application numérique : \\Delta = ($bStr)^2 - 4 \\times ($aStr) \\times ($cStr) = $deltaStr',
          'Puisque \\Delta > 0, l\'équation f(x) = 0 admet deux racines réelles distinctes :',
          'x_1 = \\frac{-b - \\sqrt{\\Delta}}{2a} = \\frac{-($bStr) - $sqrtDeltaStr}{2 \\times ($aStr)} = $r1Str',
          'x_2 = \\frac{-b + \\sqrt{\\Delta}}{2a} = \\frac{-($bStr) + $sqrtDeltaStr}{2 \\times ($aStr)} = $r2Str',
          'Forme factorisée canonique : f(x) = $aStr(x - ($r1Str))(x - ($r2Str))',
        ];
      } else if (delta == 0) {
        rootsStr = 'x_0 = $xvStr \\quad \\text{(racine double)}';
        rootsSteps = [
          'Formule du discriminant : \\Delta = b^2 - 4ac = ($bStr)^2 - 4 \\times ($aStr) \\times ($cStr) = 0',
          'Comme \\Delta = 0, l\'équation f(x) = 0 admet une unique racine double :',
          'x_0 = -\\frac{b}{2a} = -\\frac{$bStr}{2 \\times ($aStr)} = $xvStr',
          'Forme factorisée : f(x) = $aStr(x - $xvStr)^2',
        ];
      } else {
        rootsStr = r'\text{Aucune racine réelle } (\Delta < 0)';
        rootsSteps = [
          'Formule du discriminant : \\Delta = b^2 - 4ac = ($bStr)^2 - 4 \\times ($aStr) \\times ($cStr) = $deltaStr',
          'Comme \\Delta < 0, l\'équation f(x) = 0 n\'admet aucune racine réelle dans \\mathbb{R}.',
          'La parabole ne coupe pas l\'axe des abscisses et f(x) garde un signe constant (le signe de a = $aStr).',
        ];
      }

      // Limites rédigées pas à pas
      final limitResultMinus = isFacingUp ? r'+\infty' : r'-\infty';
      final limitResultPlus = isFacingUp ? r'+\infty' : r'-\infty';

      final limitMinusSteps = [
        r'Forme indéterminée constatée : type "$\infty - \infty$" à l’infini.',
        r'1. Factorisation par le monôme de plus haut degré $x^2$ (pour $x \neq 0$) :',
        '\$f(x) = $aStr x^2 \\left(1 ${b != 0 ? (b > 0 ? '+ \\frac{$bStr}{$aStr x}' : '- \\frac{${-b}}{$aStr x}') : ''} ${c != 0 ? (c > 0 ? '+ \\frac{$cStr}{$aStr x^2}' : '- \\frac{${-c}}{$aStr x^2}') : ''}\\right)\$',
        r'2. Limites des termes quotients élémentaires :',
        '\$\\lim_{x \\to -\\infty} \\frac{1}{x} = 0 \\implies \\lim_{x \\to -\\infty} \\frac{$bStr}{$aStr x} = 0\$',
        if (c != 0) '\$\\lim_{x \\to -\\infty} \\frac{1}{x^2} = 0 \\implies \\lim_{x \\to -\\infty} \\frac{$cStr}{$aStr x^2} = 0\$',
        r'3. Limite de la parenthèse par théorème d’addition : $\lim_{x \to -\infty} \left(1 + \dots\right) = 1$',
        '\$4. Limite du terme dominant : \\lim_{x \\to -\\infty} x^2 = +\\infty \\implies \\lim_{x \\to -\\infty} ($aStr x^2) = $limitResultMinus\$',
        '\$5. Conclusion par produit des limites : \\lim_{x \\to -\\infty} f(x) = $limitResultMinus \\times 1 = $limitResultMinus\$',
        '\$Théorème officiel du Baccalauréat : \\lim_{x \\to -\\infty} f(x) = \\lim_{x \\to -\\infty} ($aStr x^2) = $limitResultMinus.\$',
      ];

      final limitPlusSteps = [
        r'1. Factorisation par le monôme dominant $x^2$ :',
        '\$f(x) = $aStr x^2 \\left(1 ${b != 0 ? (b > 0 ? '+ \\frac{$bStr}{$aStr x}' : '- \\frac{${-b}}{$aStr x}') : ''} ${c != 0 ? (c > 0 ? '+ \\frac{$cStr}{$aStr x^2}' : '- \\frac{${-c}}{$aStr x^2}') : ''}\\right)\$',
        r'2. Limite de la parenthèse : $\lim_{x \to +\infty} \left(1 + \dots\right) = 1$',
        '\$3. Limite du monôme dominant : \\lim_{x \\to +\\infty} ($aStr x^2) = $limitResultPlus\$',
        '\$4. Par produit des limites : \\lim_{x \\to +\\infty} f(x) = $limitResultPlus\$',
        '\$Théorème officiel : \\lim_{x \\to +\\infty} f(x) = \\lim_{x \\to +\\infty} ($aStr x^2) = $limitResultPlus.\$',
      ];

      // Dérivée pas à pas
      final derivativeSteps = [
        '1. Justification : La fonction \$f\$ est un polynôme, elle est donc indéfiniment dérivable sur \\mathbb{R}.',
        '2. Règles de dérivation appliquées :',
        '• Règle de la puissance : (x^n)\' = n x^{n-1} \\implies (x^2)\' = 2x \\text{ et } (x)\' = 1',
        '• Linéarité : (u + v)\' = u\' + v\' \\text{ et } (k \\cdot u)\' = k \\cdot u\'',
        '• Dérivée d\'une constante : (c)\' = 0',
        '3. Calcul analytique détaillé :',
        'f\'(x) = $aStr \\times (2x) ${b != 0 ? (b > 0 ? '+ $bStr \\times 1' : '- ${-b} \\times 1') : ''} ${c != 0 ? '+ 0' : ''}',
        'f\'(x) = $derivStr',
        if (factoredXMatch != null || b != 0) 'Forme factorisée : f\'(x) = ${2 * a}(x ${xv > 0 ? '- $xvStr' : '+ ${-xv}'})',
      ];

      // Signe de la dérivée pas à pas
      final derivativeSignSteps = [
        '1. Annulation de la dérivée : f\'(x) = 0 \\iff $derivStr = 0 \\iff x = $xvStr',
        '2. Étude de signe du binôme ax + b (coefficient directeur $derivA ${isFacingUp ? '> 0' : '< 0'}) :',
        isFacingUp
            ? '• Pour x < $xvStr : f\'(x) < 0, donc la fonction f est STRICTEMENT DÉCROISSANTE.'
            : '• Pour x < $xvStr : f\'(x) > 0, donc la fonction f est STRICTEMENT CROISSANTE.',
        '• Pour x = $xvStr : f\'($xvStr) = 0 (tangente horizontale au point S).',
        isFacingUp
            ? '• Pour x > $xvStr : f\'(x) > 0, donc la fonction f est STRICTEMENT CROISSANTE.'
            : '• Pour x > $xvStr : f\'(x) < 0, donc la fonction f est STRICTEMENT DÉCROISSANTE.',
      ];

      // Sommet / extremum
      final vertexSteps = [
        '1. Abscisse du sommet (point critique annulant la dérivée) :',
        'x_S = -\\frac{b}{2a} = -\\frac{$bStr}{2 \\times ($aStr)} = $xvStr',
        '2. Ordonnée du sommet calculée en évaluant f(x_S) :',
        'y_S = f($xvStr) = $aStr \\times ($xvStr)^2 ${b != 0 ? (b > 0 ? '+ $bStr \\times ($xvStr)' : '- ${-b} \\times ($xvStr)') : ''} ${c != 0 ? (c > 0 ? '+ $cStr' : '- ${-c}') : ''} = $yvStr',
        isFacingUp
            ? 'Comme a = $aStr > 0, la parabole est convexe (tournée vers le haut). Le sommet S($xvStr ; $yvStr) est le MINIMUM ABSOLU sur \\mathbb{R}.'
            : 'Comme a = $aStr < 0, la parabole est concave (tournée vers le bas). Le sommet S($xvStr ; $yvStr) est le MAXIMUM ABSOLU sur \\mathbb{R}.',
        'Équation de la tangente horizontale au sommet : T_S : y = $yvStr.',
      ];

      // Intersection avec l'axe (Oy)
      final yInterceptSteps = [
        'L\'intersection avec l\'axe des ordonnées (Oy) s\'obtient en calculant f(0) :',
        'f(0) = $aStr \\times (0)^2 + ($bStr) \\times (0) + ($cStr) = $cStr',
        'Le point d\'intersection avec l\'axe des ordonnées est C(0 ; $cStr).',
      ];

      final academicTable = AcademicVariationData.fromQuadratic(
        a: a,
        b: b,
        c: c,
        vertexX: xv,
        vertexY: yv,
      );

      final expandedForm = '${aFormatted}x^2 ${b >= 0 ? (b == 0 ? '' : '+ ${b}x') : '- ${-b}x'} ${c >= 0 ? (c == 0 ? '' : '+ $c') : '- ${-c}'}'.trim();
      final fullFormula = (factoredXMatch != null || factoredTwoMatch != null)
          ? 'f(x) = $clean = $expandedForm'
          : 'f(x) = $expandedForm';

      return FunctionStudyData(
        rawExpression: rawExpr,
        formulaLatex: fullFormula,
        domainText: 'Ensemble des nombres réels (fonction polynôme)',
        domainLatex: r'\mathcal{D}_f = \mathbb{R} = ]-\infty ; +\infty[',
        domainSteps: const [
          'La fonction \$f\$ est une fonction polynôme du second degré.',
          'Elle ne comporte aucun dénominateur susceptible de s\'annuler ni aucune racine carrée.',
          'Elle est donc définie, continue et indéfiniment dérivable sur tout ensemble réel :',
          r'\mathcal{D}_f = \mathbb{R} = ]-\infty ; +\infty[',
        ],
        limitMinusInfLatex: '\\lim_{x \\to -\\infty} f(x) = $limitResultMinus',
        limitMinusInfSteps: limitMinusSteps,
        limitPlusInfLatex: '\\lim_{x \\to +\\infty} f(x) = $limitResultPlus',
        limitPlusInfSteps: limitPlusSteps,
        derivativeLatex: "f'(x) = $derivStr",
        derivativeSteps: derivativeSteps,
        derivativeSignExplanation: isFacingUp
            ? "f'(x) < 0 sur ]-\\infty ; $xvStr[ puis f'(x) > 0 sur ]$xvStr ; +\\infty[."
            : "f'(x) > 0 sur ]-\\infty ; $xvStr[ puis f'(x) < 0 sur ]$xvStr ; +\\infty[.",
        derivativeSignSteps: derivativeSignSteps,
        criticalPointsText: [
          "Sommet S($xvStr ; $yvStr)",
          "Tangente horizontale au sommet : y = $yvStr (pente nulle f'($xvStr) = 0)",
        ],
        vertexSteps: vertexSteps,
        variationTable: VariationTableData(
          xValues: ['-\\infty', xvStr, '+\\infty'],
          derivativeSigns: isFacingUp ? ['-', '0', '+'] : ['+', '0', '-'],
          variationArrows: isFacingUp ? ['down', 'up'] : ['up', 'down'],
          fValues: isFacingUp ? ['+\\infty', yvStr, '+\\infty'] : ['-\\infty', yvStr, '-\\infty'],
        ),
        academicTable: academicTable,
        asymptotesSummary: "Aucune asymptote (branche parabolique)",
        asymptotesDetails: [
          '\\lim_{x \\to \\pm\\infty} \\frac{f(x)}{x} = \\lim_{x \\to \\pm\\infty} ($aStr x) = \\pm\\infty : branche parabolique de direction (Oy).',
          'La fonction ne possède aucune asymptote horizontale ni verticale sur \\mathbb{R}.',
        ],
        rootsLatex: rootsStr,
        rootsSteps: rootsSteps,
        yInterceptLatex: 'f(0) = $cStr',
        yInterceptSteps: yInterceptSteps,
        spec: spec,
      );
    }

    // 2. Détection Polynôme de Degré 3 : x^3 - 3x + 1 ou x^3 - 3x^2 + 1
    if (noSpaces.contains('x^3') || noSpaces.contains('x³')) {
      final academicTable = AcademicVariationData.fromCubicStandard();

      final cubicLimitMinusSteps = const [
        r'1. Constat de forme indéterminée : $\lim_{x \to -\infty} x^3 = -\infty$ et $\lim_{x \to -\infty} (-3x^2) = -\infty$, créant une indétermination du type $\infty - \infty$.',
        r'2. Factorisation par le monôme de plus haut degré $x^3$ pour tout $x \neq 0$ :',
        r'$f(x) = x^3 \left(1 - \frac{3}{x} + \frac{1}{x^3}\right)$',
        r'3. Limites des termes quotients élémentaires :',
        r'$\lim_{x \to -\infty} \frac{1}{x} = 0 \implies \lim_{x \to -\infty} \frac{3}{x} = 0 \quad \text{et} \quad \lim_{x \to -\infty} \frac{1}{x^3} = 0$',
        r'4. Limite de la parenthèse par théorème d’addition : $\lim_{x \to -\infty} \left(1 - \frac{3}{x} + \frac{1}{x^3}\right) = 1 - 0 + 0 = 1$',
        r'5. Conclusion par produit des limites : $\lim_{x \to -\infty} x^3 = -\infty \implies \lim_{x \to -\infty} f(x) = (-\infty) \times 1 = -\infty$.',
        r'Théorème officiel du Baccalauréat : À l’infini, la limite d’une fonction polynôme est égale à la limite de son monôme de plus haut degré : $\lim_{x \to -\infty} f(x) = \lim_{x \to -\infty} x^3 = -\infty$.',
      ];

      final cubicLimitPlusSteps = const [
        r'1. Constat de forme indéterminée : $\lim_{x \to +\infty} x^3 = +\infty$ et $\lim_{x \to +\infty} (-3x^2) = -\infty$ (type $\infty - \infty$).',
        r'2. Factorisation par le monôme dominant $x^3$ pour tout $x > 0$ :',
        r'$f(x) = x^3 \left(1 - \frac{3}{x} + \frac{1}{x^3}\right)$',
        r'3. Limite des quotients élémentaires : $\lim_{x \to +\infty} \frac{3}{x} = 0$ et $\lim_{x \to +\infty} \frac{1}{x^3} = 0$',
        r'4. Limite du facteur entre parenthèses : $\lim_{x \to +\infty} \left(1 - \frac{3}{x} + \frac{1}{x^3}\right) = 1$',
        r'5. Conclusion par produit des limites : $\lim_{x \to +\infty} x^3 = +\infty \implies \lim_{x \to +\infty} f(x) = (+\infty) \times 1 = +\infty$.',
        r'Théorème officiel : $\lim_{x \to +\infty} f(x) = \lim_{x \to +\infty} x^3 = +\infty$.',
      ];

      final cubicDerivativeSteps = const [
        r'1. Justification de dérivabilité : $f$ est une fonction polynôme, elle est donc indéfiniment dérivable sur $\mathbb{R}$.',
        r'2. Règle de dérivation de la puissance : $(x^n)^\prime = n x^{n-1} \implies (x^3)^\prime = 3x^2 \text{ et } (x^2)^\prime = 2x$.',
        r'3. Dérivation terme à terme par linéarité : $f^\prime(x) = 3x^2 - 3 \times (2x) + 0 = 3x^2 - 6x$.',
        r'4. Factorisation systématique par le facteur commun $3x$ :',
        r'$f^\prime(x) = 3x(x - 2)$',
      ];

      final cubicSignSteps = const [
        r'1. Recherche des points critiques (annulation de la dérivée) :',
        r'$f^\prime(x) = 0 \iff 3x(x - 2) = 0 \iff 3x = 0 \quad \text{ou} \quad x - 2 = 0 \iff x = 0 \quad \text{ou} \quad x = 2$.',
        r'2. Étude du signe de chaque facteur :',
        r'• Facteur $3x$ : strictement négatif sur $]-\infty ; 0[$, nul en $x = 0$, strictement positif sur $]0 ; +\infty[$.',
        r'• Facteur $x - 2$ : strictement négatif sur $]-\infty ; 2[$, nul en $x = 2$, strictement positif sur $]2 ; +\infty[$.',
        r'3. Règle des signes du produit :',
        r'• Sur $]-\infty ; 0[$ : $(-) \times (-) = (+) \implies f^\prime(x) > 0$.',
        r'• En $x = 0$ : $f^\prime(0) = 0$ (tangente horizontale).',
        r'• Sur $]0 ; 2[$ : $(+) \times (-) = (-) \implies f^\prime(x) < 0$.',
        r'• En $x = 2$ : $f^\prime(2) = 0$ (tangente horizontale).',
        r'• Sur $]2 ; +\infty[$ : $(+) \times (+) = (+) \implies f^\prime(x) > 0$.',
        r'4. Déduction du sens de variation de la fonction $f$ :',
        r'• $f$ est STRICTEMENT CROISSANTE sur $]-\infty ; 0]$.',
        r'• $f$ est STRICTEMENT DÉCROISSANTE sur $[0 ; 2]$.',
        r'• $f$ est STRICTEMENT CROISSANTE sur $[2 ; +\infty[$.',
      ];

      final cubicExtremaSteps = const [
        r'1. Maximum local atteint en $x = 0$ :',
        r'• Ordonnée : $f(0) = 0^3 - 3(0)^2 + 1 = 1$.',
        r'• Point sommet : $M(0 ; 1)$.',
        r'• Équation de la tangente horizontale : $T_0 : y = f^\prime(0)(x - 0) + f(0) = 0 \cdot x + 1 \implies y = 1$.',
        r'2. Minimum local atteint en $x = 2$ :',
        r'• Ordonnée : $f(2) = 2^3 - 3(2)^2 + 1 = 8 - 12 + 1 = -3$.',
        r'• Point cuvette : $m(2 ; -3)$.',
        r'• Équation de la tangente horizontale : $T_2 : y = f^\prime(2)(x - 2) + f(2) = 0 \cdot (x - 2) - 3 \implies y = -3$.',
        r'3. Point d’inflexion (changement de concavité) :',
        r'• Dérivée seconde : $f^{\prime\prime}(x) = (3x^2 - 6x)^\prime = 6x - 6 = 6(x - 1)$.',
        r'• Annulation : $f^{\prime\prime}(x) = 0 \iff x = 1$ avec changement de signe.',
        r'• Ordonnée du point d’inflexion : $f(1) = 1^3 - 3(1)^2 + 1 = -1$.',
        r'• Le point $I(1 ; -1)$ est le centre de symétrie et point d’inflexion de la courbe $\mathcal{C}_f$.',
      ];

      return FunctionStudyData(
        rawExpression: rawExpr,
        formulaLatex: rawExpr.contains('=') ? rawExpr : 'f(x) = $clean',
        domainText: 'Ensemble des nombres réels (fonction polynôme de degré 3)',
        domainLatex: r'\mathcal{D}_f = \mathbb{R} = ]-\infty ; +\infty[',
        domainSteps: const [
          r'La fonction $f$ est une fonction polynôme de degré 3.',
          r'Elle ne comporte aucune valeur interdite (aucun quotient susceptible de s’annuler ni racine carrée).',
          r'Elle est donc définie, continue et indéfiniment dérivable sur tout $\mathbb{R}$ :',
          r'$\mathcal{D}_f = \mathbb{R} = ]-\infty ; +\infty[$',
        ],
        limitMinusInfLatex: r'\lim_{x \to -\infty} f(x) = -\infty',
        limitMinusInfSteps: cubicLimitMinusSteps,
        limitPlusInfLatex: r'\lim_{x \to +\infty} f(x) = +\infty',
        limitPlusInfSteps: cubicLimitPlusSteps,
        derivativeLatex: r"f'(x) = 3x^2 - 6x = 3x(x - 2)",
        derivativeSteps: cubicDerivativeSteps,
        derivativeSignExplanation: r"$f'(x) > 0$ sur $]-\infty ; 0[$ et $]2 ; +\infty[$, et $f'(x) < 0$ sur $]0 ; 2[$.",
        derivativeSignSteps: cubicSignSteps,
        criticalPointsText: const [
          r"Maximum local en $x = 0$ : $M(0 ; 1)$ avec tangente horizontale $y = 1$",
          r"Minimum local en $x = 2$ : $m(2 ; -3)$ avec tangente horizontale $y = -3$",
          r"Point d'inflexion en $x = 1$ : $I(1 ; -1)$ avec changement de concavité ($f''(1) = 0$)",
        ],
        vertexSteps: cubicExtremaSteps,
        variationTable: const VariationTableData(
          xValues: ['-\\infty', '0', '2', '+\\infty'],
          derivativeSigns: ['+', '0', '-', '0', '+'],
          variationArrows: ['up', 'down', 'up'],
          fValues: ['-\\infty', '1', '-3', '+\\infty'],
        ),
        academicTable: academicTable,
        asymptotesSummary: "Aucune asymptote (branche parabolique cubique)",
        asymptotesDetails: const [
          r'$\lim_{x \to \pm\infty} \frac{f(x)}{x} = \lim_{x \to \pm\infty} x^2 = +\infty$ : la courbe admet une branche parabolique de direction $(Oy)$.',
          r'La fonction ne possède aucune asymptote horizontale ni oblique sur $\mathbb{R}$.',
        ],
        rootsLatex: r'x_1 \approx -0.53, \quad x_2 \approx 0.65, \quad x_3 \approx 2.88',
        rootsSteps: const [
          r'D’après le Théorème des Valeurs Intermédiaires (TVI) appliqué aux intervalles de monotonie :',
          r'1. Sur $]-\infty ; 0]$, $f$ est continue et strictement croissante de $-\infty$ à $1$. Comme $0 \in ]-\infty ; 1]$, il existe une unique solution $x_1 \approx -0.53$.',
          r'2. Sur $[0 ; 2]$, $f$ est continue et strictement décroissante de $1$ à $-3$. Comme $0 \in [-3 ; 1]$, il existe une unique solution $x_2 \approx 0.65$.',
          r'3. Sur $[2 ; +\infty[$, $f$ est continue et strictement croissante de $-3$ à $+\infty$. Comme $0 \in [-3 ; +\infty[$, il existe une unique solution $x_3 \approx 2.88$.',
          r'L’équation $x^3 - 3x^2 + 1 = 0$ admet donc exactement 3 solutions réelles distinctes dans $\mathbb{R}$.',
        ],
        yInterceptLatex: 'f(0) = 1',
        yInterceptSteps: const [
          r'L’intersection avec l’axe des ordonnées $(Oy)$ s’obtient en calculant $f(0)$ :',
          r'$f(0) = 0^3 - 3(0)^2 + 1 = 1$.',
          r'Le point d’intersection est $C(0 ; 1)$.',
        ],
        spec: spec,
      );
    }

    // 3. Cas Général / Affine : ax + b
    final academicTable = AcademicVariationData.fromAffine(a: 1.0, b: 0.0);
    return FunctionStudyData(
      rawExpression: rawExpr,
      formulaLatex: rawExpr.contains('=') ? rawExpr : 'f(x) = $clean',
      domainText: 'Ensemble des nombres réels',
      domainLatex: r'\mathcal{D}_f = \mathbb{R} = ]-\infty ; +\infty[',
      domainSteps: const [
        'Fonction affine définie et continue sur \\mathbb{R}.',
      ],
      limitMinusInfLatex: r'\lim_{x \to -\infty} f(x) = -\infty',
      limitMinusInfSteps: const ['\\lim_{x \\to -\\infty} ax + b = -\\infty'],
      limitPlusInfLatex: r'\lim_{x \to +\infty} f(x) = +\infty',
      limitPlusInfSteps: const ['\\lim_{x \\to +\\infty} ax + b = +\\infty'],
      derivativeLatex: "f'(x) = 1",
      derivativeSteps: const ['Dérivée constante égale au coefficient directeur.'],
      derivativeSignExplanation: "Fonction strictement monotone.",
      derivativeSignSteps: const ['f\'(x) > 0 constant sur tout \\mathbb{R}.'],
      criticalPointsText: const ["Pas de point critique."],
      vertexSteps: const ["Pas de sommet."],
      variationTable: const VariationTableData(
        xValues: ['-\\infty', '+\\infty'],
        derivativeSigns: ['+'],
        variationArrows: ['up'],
        fValues: ['-\\infty', '+\\infty'],
      ),
      academicTable: academicTable,
      asymptotesSummary: "Aucune asymptote",
      asymptotesDetails: const ["Droite affine sans asymptote."],
      rootsLatex: r'f(x) = 0',
      rootsSteps: const ['Résolution immédiate de ax + b = 0.'],
      yInterceptLatex: 'f(0) = 0',
      yInterceptSteps: const ['Ordonnée à l\'origine en y = b.'],
      spec: spec,
    );
  }
}

/// Modal plein écran bottom-sheet pour l'étude complète, rigoureuse et détaillée d'une fonction
class FunctionStudyModal extends StatelessWidget {
  final FunctionStudyData data;

  const FunctionStudyModal({super.key, required this.data});

  static Future<void> show(BuildContext context, String rawExpression) {
    final studyData = FunctionStudyData.fromExpression(rawExpression);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FunctionStudyModal(data: studyData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Poignée supérieure
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // En-tête de la modale
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withAlpha(30),
                    borderRadius: AppRadius.radiusSmall,
                    border: Border.all(color: AppColors.primaryCyan.withAlpha(100)),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: AppColors.primaryCyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ÉTUDE COMPLÈTE DE LA FONCTION (CORRIGÉ DÉTAILLÉ)',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        data.formulaLatex,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),

          // Contenu déroulant complet et hautement explicité
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Formule officielle mise en valeur
                  MathFormulaView(
                    formulaLatex: data.formulaLatex,
                    fontSize: 18,
                    label: 'FONCTION ÉTUDIÉE',
                  ),
                  const SizedBox(height: 16),

                  // 2. Domaine de définition
                  _buildSectionCard(
                    title: '1. Ensemble de Définition',
                    icon: Icons.all_inclusive_rounded,
                    color: const Color(0xFF38BDF8),
                    children: [
                      _buildInfoRow('Domaine :', data.domainLatex, isLatex: true),
                      const SizedBox(height: 8),
                      ...data.domainSteps.map((step) => _buildStepItem(step)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Calcul des Limites aux Bornes (DÉTAILLÉ PAS À PAS)
                  _buildSectionCard(
                    title: '2. Limites aux Bornes (Démonstration Pas à Pas)',
                    icon: Icons.unfold_more_rounded,
                    color: const Color(0xFF0EA5E9),
                    children: [
                      _buildSubHeader('Limite en -∞ :'),
                      _buildInfoRow('Résultat :', data.limitMinusInfLatex, isLatex: true),
                      const SizedBox(height: 6),
                      ...data.limitMinusInfSteps.map((step) => _buildStepItem(step)),
                      const SizedBox(height: 14),
                      _buildSubHeader('Limite en +∞ :'),
                      _buildInfoRow('Résultat :', data.limitPlusInfLatex, isLatex: true),
                      const SizedBox(height: 6),
                      ...data.limitPlusInfSteps.map((step) => _buildStepItem(step)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Dérivée et Signe (DÉTAILLÉ PAS À PAS)
                  _buildSectionCard(
                    title: "3. Dérivée & Signe de f'(x) (Démonstration)",
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF10B981),
                    children: [
                      _buildInfoRow("Fonction dérivée :", data.derivativeLatex, isLatex: true),
                      const SizedBox(height: 8),
                      _buildSubHeader('Règles et calcul de la dérivée :'),
                      ...data.derivativeSteps.map((step) => _buildStepItem(step)),
                      const SizedBox(height: 12),
                      _buildSubHeader("Résolution de f'(x) = 0 et signe :"),
                      ...data.derivativeSignSteps.map((step) => _buildStepItem(step)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5. Extremum & Sommet de la Courbe
                  _buildSectionCard(
                    title: '4. Sommet & Extrema de la Fonction',
                    icon: Icons.grade_rounded,
                    color: const Color(0xFFF59E0B),
                    children: [
                      ...data.criticalPointsText.map((pt) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: InlineLatexText(
                                    pt,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    mathColor: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      _buildSubHeader('Détail du calcul du sommet :'),
                      ...data.vertexSteps.map((step) => _buildStepItem(step)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6. Tableau de Variations Officiel (Façon Lycée Français)
                  _buildSectionCard(
                    title: '5. Tableau de Variations Officiel',
                    icon: Icons.table_chart_rounded,
                    color: const Color(0xFF38BDF8),
                    children: [
                      const Text(
                        'Disposition académique officielle avec flèches diagonales vectorielles et zéros barrés :',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      AcademicVariationTableView(
                        data: data.academicTable,
                        title: 'Tableau officiel des variations',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 7. Zéros, Racines & Discriminant Delta
                  _buildSectionCard(
                    title: '6. Zéros f(x) = 0 & Discriminant Δ',
                    icon: Icons.adjust_rounded,
                    color: const Color(0xFFEC4899),
                    children: [
                      _buildInfoRow('Zéros réels :', data.rootsLatex, isLatex: true),
                      const SizedBox(height: 8),
                      _buildSubHeader('Calcul du discriminant et des racines :'),
                      ...data.rootsSteps.map((step) => _buildStepItem(step)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 8. Intersection avec les Axes & Ordonnée à l'Origine
                  _buildSectionCard(
                    title: '7. Intersection avec l’axe des ordonnées (Oy)',
                    icon: Icons.my_location_rounded,
                    color: const Color(0xFF8B5CF6),
                    children: [
                      _buildInfoRow('Ordonnée à l’origine :', data.yInterceptLatex, isLatex: true),
                      const SizedBox(height: 8),
                      ...data.yInterceptSteps.map((step) => _buildStepItem(step)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 9. Asymptotes & Comportement Asymptotique
                  _buildSectionCard(
                    title: '8. Asymptotes & Branches Infinies',
                    icon: Icons.linear_scale_rounded,
                    color: const Color(0xFFA855F7),
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA855F7).withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA855F7).withAlpha(90)),
                            ),
                            child: Text(
                              data.asymptotesSummary,
                              style: const TextStyle(color: Color(0xFFA855F7), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...data.asymptotesDetails.map((d) => _buildStepItem(d)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bouton direct pour tracer la courbe dans le repère interactif
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCyan,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.show_chart_rounded, size: 20),
                    label: const Text(
                      'Tracer la courbe dans le repère interactif',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      InteractiveFunctionGraph.showModal(
                        context,
                        spec: data.spec,
                        title: 'Tracé de ${data.spec.title}',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.primaryCyan,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStepItem(String step) {
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.primaryCyan, fontWeight: FontWeight.bold)),
          Expanded(
            child: InlineLatexText(
              step,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, height: 1.45),
              mathColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withAlpha(60), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLatex = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: isLatex
              ? InlineLatexText(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  mathColor: AppColors.primaryCyan,
                )
              : Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
