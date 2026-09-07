import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../../core/services/scientific_tools_service.dart';
import 'variation_table_interactive.dart';

/// Équation et propriétés d'une droite tangente
class TangentLine {
  final double slope;
  final double yIntercept;
  final String formulaText;

  const TangentLine({
    required this.slope,
    required this.yIntercept,
    required this.formulaText,
  });
}

/// Définition mathématique d'une fonction et de sa dérivée
class MathFunctionSpec {
  final String title;
  final String formulaLatex;
  final double Function(double x) f;
  final double Function(double x) df;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final bool isPolynomial;
  final String expression;
  final String derivativeExpression;
  final double? vertexX;
  final double? vertexY;
  final List<double> roots;

  const MathFunctionSpec({
    required this.title,
    required this.formulaLatex,
    required this.f,
    required this.df,
    this.xMin = -4.0,
    this.xMax = 4.0,
    this.yMin = -4.0,
    this.yMax = 5.0,
    this.isPolynomial = false,
    this.expression = '',
    this.derivativeExpression = '',
    this.vertexX,
    this.vertexY,
    this.roots = const [],
  });

  double evaluate(double x) => f(x);
  double evaluateDerivative(double x) => df(x);

  TangentLine tangentLine(double x0) {
    final y0 = f(x0);
    final m = df(x0);
    final p = y0 - m * x0;
    final pSign = p < 0 ? '- ${(-p).toStringAsFixed(p.truncateToDouble() == p ? 0 : 1)}' : '+ ${p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 1)}';
    final mStr = m.truncateToDouble() == m ? '${m.toInt()}' : m.toStringAsFixed(1);
    return TangentLine(
      slope: m,
      yIntercept: p,
      formulaText: p == 0 ? 'y = ${mStr}x' : 'y = ${mStr}x $pSign',
    );
  }

  /// Modèle cubique réaliste fidèle à la maquette EDLEARN
  static MathFunctionSpec get defaultCubic => MathFunctionSpec(
        title: 'Observe la dérivée',
        formulaLatex: 'f(x) = 0.25(x^3 - 3x) + 0.5',
        f: (x) => 0.22 * (math.pow(x, 3) - 3 * x) + 0.3,
        df: (x) => 0.22 * (3 * math.pow(x, 2) - 3),
        xMin: -4.0,
        xMax: 4.0,
        yMin: -4.0,
        yMax: 5.0,
        isPolynomial: true,
        expression: '0.25(x³ - 3x) + 0.5',
        derivativeExpression: "f'(x) = 0.75x² - 0.75",
      );

  /// Analyse et construit déterministement une spécification graphique à partir de n'importe quelle expression
  /// (ex: 2x^2 - 4x - 6, x^2 - 4, x^3 - 3x + 1, 3x - 5, etc.)
  static MathFunctionSpec fromExpression(String rawExpr, {String? title}) {
    final clean = rawExpr
        .replaceAll(RegExp(r'^[a-zA-Z]\(x\)\s*=\s*'), '')
        .replaceAll(RegExp(r'^y\s*=\s*'), '')
        .replaceAll(r'$', '')
        .trim();

    final noSpaces = clean.replaceAll(' ', '');

    // 1. Détection polynôme quadratique ax^2 + bx + c ou 2x^2 - 4x - 6
    if (noSpaces.contains('x^2') || noSpaces.contains('x²') || noSpaces.contains('x*x')) {
      final quadRegex = RegExp(r'^([+\-]?[0-9]*\.?[0-9]*)?\*?x(?:\^2|²)(?:([+\-][0-9]*\.?[0-9]*)\*?x)?(?:([+\-][0-9]+\.?[0-9]*))?$');
      final qm = quadRegex.firstMatch(noSpaces);

      double a = 1.0;
      double b = 0.0;
      double c = 0.0;

      if (qm != null) {
        var aStr = qm.group(1) ?? '1';
        if (aStr.isEmpty || aStr == '+') aStr = '1';
        if (aStr == '-') aStr = '-1';
        a = double.tryParse(aStr) ?? 1.0;

        var bStr = qm.group(2) ?? '0';
        if (bStr == '+') bStr = '1';
        if (bStr == '-') bStr = '-1';
        b = double.tryParse(bStr) ?? 0.0;

        var cStr = qm.group(3) ?? '0';
        c = double.tryParse(cStr) ?? 0.0;
      } else {
        // Extraction par tokens simples si le regex strict ne matche pas
        if (noSpaces.startsWith('-x^2') || noSpaces.startsWith('-x²')) {
          a = -1.0;
        } else if (noSpaces.startsWith('x^2') || noSpaces.startsWith('x²')) {
          a = 1.0;
        }
      }

      // Calcul des propriétés géométriques (sommet, extremum, fenêtre de vue)
      final xv = a != 0 ? -b / (2 * a) : 0.0;
      final yv = a * xv * xv + b * xv + c;

      final spanX = 4.0;
      final xMin = (xv - spanX).floorToDouble();
      final xMax = (xv + spanX).ceilToDouble();

      final yAtMin = a * xMin * xMin + b * xMin + c;
      final yAtMax = a * xMax * xMax + b * xMax + c;
      final minY = [yv, yAtMin, yAtMax].reduce(math.min);
      final maxY = [yv, yAtMin, yAtMax].reduce(math.max);

      final padY = math.max(2.0, (maxY - minY) * 0.15);
      final yMin = (minY - padY).floorToDouble();
      final yMax = (maxY + padY).ceilToDouble();

      final delta = b * b - 4 * a * c;
      final rootsList = <double>[];
      if (delta > 0) {
        rootsList.add((-b - math.sqrt(delta)) / (2 * a));
        rootsList.add((-b + math.sqrt(delta)) / (2 * a));
        rootsList.sort();
      } else if (delta == 0) {
        rootsList.add(-b / (2 * a));
      }

      String numStr(double val) => val.truncateToDouble() == val ? '${val.toInt()}' : val.toStringAsFixed(1);
      String signStr(double val) => val < 0 ? '- ${numStr(-val)}' : '+ ${numStr(val)}';
      String aTerm = a == 1 ? '' : (a == -1 ? '-' : numStr(a));
      String bTerm = b != 0 ? '${signStr(b)}x ' : '';
      String cTerm = c != 0 ? signStr(c) : '';
      String exprStr = '${aTerm}x² $bTerm$cTerm'.replaceAll('  ', ' ').trim();
      double da = 2 * a;
      String daTerm = da == 1 ? '' : (da == -1 ? '-' : numStr(da));
      String derivB = b != 0 ? signStr(b) : '';
      String derivStr = "f'(x) = ${daTerm}x $derivB".replaceAll('  ', ' ').trim();

      return MathFunctionSpec(
        title: title ?? 'Polynôme du 2nd degré',
        formulaLatex: rawExpr.contains('=') ? rawExpr : 'f(x) = $clean',
        f: (x) => a * x * x + b * x + c,
        df: (x) => 2 * a * x + b,
        xMin: xMin,
        xMax: xMax,
        yMin: yMin,
        yMax: yMax,
        isPolynomial: true,
        expression: exprStr,
        derivativeExpression: derivStr,
        vertexX: xv,
        vertexY: yv,
        roots: rootsList,
      );
    }

    // 2. Détection polynôme de degré 3 (x^3 - 3x + 1 ou 0.25(x^3 - 3x) + 0.5)
    if (noSpaces.contains('x^3') || noSpaces.contains('x³')) {
      return MathFunctionSpec(
        title: title ?? 'Fonction polynôme de degré 3',
        formulaLatex: rawExpr.contains('=') ? rawExpr : 'f(x) = $clean',
        f: (x) {
          if (clean.contains('0.25') || clean.contains('0.22')) {
            return 0.22 * (math.pow(x, 3) - 3 * x) + 0.3;
          }
          return 0.2 * (math.pow(x, 3) - 3 * math.pow(x, 2)) + 1.0;
        },
        df: (x) {
          if (clean.contains('0.25') || clean.contains('0.22')) {
            return 0.22 * (3 * math.pow(x, 2) - 3);
          }
          return 0.2 * (3 * math.pow(x, 2) - 6 * x);
        },
        xMin: -4.0,
        xMax: 4.0,
        yMin: -4.0,
        yMax: 5.0,
      );
    }

    // 3. Détection fonction affine ax + b
    if (noSpaces.contains('x') && !noSpaces.contains('^') && !noSpaces.contains('/')) {
      final affineRegex = RegExp(r'^([+\-]?[0-9]*\.?[0-9]*)?\*?x([+\-][0-9]+\.?[0-9]*)?$');
      final am = affineRegex.firstMatch(noSpaces);
      double a = 1.0;
      double b = 0.0;
      if (am != null) {
        var aStr = am.group(1) ?? '1';
        if (aStr.isEmpty || aStr == '+') aStr = '1';
        if (aStr == '-') aStr = '-1';
        a = double.tryParse(aStr) ?? 1.0;
        b = double.tryParse(am.group(2) ?? '0') ?? 0.0;
      }

      return MathFunctionSpec(
        title: title ?? 'Fonction affine',
        formulaLatex: rawExpr.contains('=') ? rawExpr : 'f(x) = $clean',
        f: (x) => a * x + b,
        df: (x) => a,
        xMin: -5.0,
        xMax: 5.0,
        yMin: -6.0,
        yMax: 6.0,
      );
    }

    // 4. Modèle par défaut standard
    return MathFunctionSpec(
      title: title ?? 'Fonction f(x)',
      formulaLatex: rawExpr.contains('=') ? rawExpr : 'f(x) = $clean',
      f: (x) => 0.5 * x * x - 2,
      df: (x) => x,
      xMin: -4.0,
      xMax: 4.0,
      yMin: -4.0,
      yMax: 6.0,
    );
  }
}

/// Widget graphique interactif : repère orthonormé, tracé déterministe de f(x),
/// point A mobile sur la courbe et tangente pointillée réactive avec pente f'(x).
class InteractiveFunctionGraph extends StatefulWidget {
  final MathFunctionSpec functionSpec;
  final double initialX;
  final ValueChanged<double>? onXChanged;
  final bool showObservationCard;

  const InteractiveFunctionGraph({
    super.key,
    required this.functionSpec,
    this.initialX = 2.0,
    this.onXChanged,
    this.showObservationCard = true,
  });

  /// Ouvre un modal complet de visualisation graphique interactive pour n'importe quelle fonction
  static Future<void> showModal(
    BuildContext context, {
    MathFunctionSpec? spec,
    String? expression,
    String? title,
  }) async {
    final effectiveSpec = spec ??
        (expression != null
            ? MathFunctionSpec.fromExpression(expression, title: title)
            : MathFunctionSpec.defaultCubic);

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
      builder: (ctx) => _FunctionGraphModalDialog(spec: effectiveSpec),
    );
  }

  @override
  State<InteractiveFunctionGraph> createState() =>
      _InteractiveFunctionGraphState();
}

class _InteractiveFunctionGraphState extends State<InteractiveFunctionGraph> {
  late double _currentX;

  @override
  void initState() {
    super.initState();
    _currentX = widget.initialX;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.functionSpec;
    final currentY = spec.f(_currentX);
    final currentSlope = spec.df(_currentX);

    // Analyse pédagogique déterministe
    String observationText;
    Color observationColor;
    IconData observationIcon;

    if (currentSlope.abs() < 0.15) {
      observationText =
          "Au point critique où f'(x) = 0, la tangente est horizontale (extremum local).";
      observationColor = const Color(0xFFF59E0B); // Ambre
      observationIcon = Icons.horizontal_rule_rounded;
    } else if (currentSlope > 0) {
      observationText =
          "La fonction est strictement croissante lorsque f'(x) > 0 (pente positive).";
      observationColor = AppColors.tealSuccess;
      observationIcon = Icons.trending_up_rounded;
    } else {
      observationText =
          "La fonction est strictement décroissante lorsque f'(x) < 0 (pente négative).";
      observationColor = const Color(0xFFEF4444); // Rouge / Orange
      observationIcon = Icons.trending_down_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Carte du graphe vectoriel
        Container(
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _GraphPainter(
                  spec: spec,
                  pointX: _currentX,
                  pointY: currentY,
                  slope: currentSlope,
                ),
              ),
              // Badge indicatif du point A
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE65100),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Point A (${_currentX.toStringAsFixed(1)} ; ${currentY.toStringAsFixed(1)})',
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Curseur de contrôle de la position de A
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withAlpha(180),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Position de A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tealSuccess,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'x = ${_currentX.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${spec.xMin.toInt()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.tealSuccess,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: AppColors.tealSuccess.withAlpha(60),
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: _currentX,
                        min: spec.xMin,
                        max: spec.xMax,
                        divisions: 80,
                        onChanged: (val) {
                          setState(() => _currentX = val);
                          widget.onXChanged?.call(val);
                        },
                      ),
                    ),
                  ),
                  Text(
                    '${spec.xMax.toInt()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Cartes d'état côte-à-côte
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Position de A',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'x = ${_currentX.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pente de la tangente',
                      style: TextStyle(
                        color: Color(0xFF7E22CE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "f'(${_currentX.toStringAsFixed(1)}) = ${currentSlope.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (widget.showObservationCard) ...[
          const SizedBox(height: 14),
          // Encadré Ton Observation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: observationColor.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    observationIcon,
                    color: observationColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TON OBSERVATION',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        observationText,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
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
}

/// Painter vectoriel Canvas traçant la grille, les axes, la courbe et la tangente
class _GraphPainter extends CustomPainter {
  final MathFunctionSpec spec;
  final double pointX;
  final double pointY;
  final double slope;

  _GraphPainter({
    required this.spec,
    required this.pointX,
    required this.pointY,
    required this.slope,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padding = 24.0;
    final double plotWidth = size.width - 2 * padding;
    final double plotHeight = size.height - 2 * padding;

    // Fonctions de transformation de coordonnées cartésiennes en pixels écran
    double toScreenX(double mathX) {
      return padding +
          ((mathX - spec.xMin) / (spec.xMax - spec.xMin)) * plotWidth;
    }

    double toScreenY(double mathY) {
      return size.height -
          padding -
          ((mathY - spec.yMin) / (spec.yMax - spec.yMin)) * plotHeight;
    }

    final originX = toScreenX(0);
    final originY = toScreenY(0);

    // 1. Grille fine en pointillés légers
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    for (int x = spec.xMin.toInt(); x <= spec.xMax.toInt(); x++) {
      final sx = toScreenX(x.toDouble());
      canvas.drawLine(
        Offset(sx, padding),
        Offset(sx, size.height - padding),
        gridPaint,
      );
    }

    for (int y = spec.yMin.toInt(); y <= spec.yMax.toInt(); y++) {
      final sy = toScreenY(y.toDouble());
      canvas.drawLine(
        Offset(padding, sy),
        Offset(size.width - padding, sy),
        gridPaint,
      );
    }

    // 2. Axes principaux avec flèches (x et y)
    final axisPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.6;

    // Axe X
    canvas.drawLine(
      Offset(padding - 8, originY),
      Offset(size.width - padding + 12, originY),
      axisPaint,
    );
    // Flèche axe X
    final arrowX = Path()
      ..moveTo(size.width - padding + 12, originY)
      ..lineTo(size.width - padding + 2, originY - 4)
      ..lineTo(size.width - padding + 2, originY + 4)
      ..close();
    canvas.drawPath(arrowX, axisPaint);

    // Axe Y
    canvas.drawLine(
      Offset(originX, size.height - padding + 8),
      Offset(originX, padding - 12),
      axisPaint,
    );
    // Flèche axe Y
    final arrowY = Path()
      ..moveTo(originX, padding - 12)
      ..lineTo(originX - 4, padding - 2)
      ..lineTo(originX + 4, padding - 2)
      ..close();
    canvas.drawPath(arrowY, axisPaint);

    // Labels des axes (x et y)
    _drawText(canvas, 'x', Offset(size.width - padding + 10, originY + 8),
        const TextStyle(
            color: Color(0xFF1E293B),
            fontStyle: FontStyle.italic,
            fontSize: 13,
            fontWeight: FontWeight.bold));
    _drawText(canvas, 'y', Offset(originX - 16, padding - 16),
        const TextStyle(
            color: Color(0xFF1E293B),
            fontStyle: FontStyle.italic,
            fontSize: 13,
            fontWeight: FontWeight.bold));

    // Graduations numériques
    for (int x = spec.xMin.toInt(); x <= spec.xMax.toInt(); x++) {
      if (x == 0) continue;
      final sx = toScreenX(x.toDouble());
      canvas.drawLine(Offset(sx, originY - 3), Offset(sx, originY + 3), axisPaint);
      _drawText(
        canvas,
        '$x',
        Offset(sx - 6, originY + 6),
        const TextStyle(color: Color(0xFF64748B), fontSize: 10),
      );
    }

    for (int y = spec.yMin.toInt(); y <= spec.yMax.toInt(); y++) {
      if (y == 0) continue;
      final sy = toScreenY(y.toDouble());
      canvas.drawLine(Offset(originX - 3, sy), Offset(originX + 3, sy), axisPaint);
      _drawText(
        canvas,
        '$y',
        Offset(originX - 16, sy - 6),
        const TextStyle(color: Color(0xFF64748B), fontSize: 10),
      );
    }

    // 3. Tracé déterministe de la courbe f(x)
    final curvePaint = Paint()
      ..color = const Color(0xFF1E3A8A) // Bleu marine profond
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final curvePath = Path();
    bool firstPoint = true;
    const int stepCount = 180;
    for (int i = 0; i <= stepCount; i++) {
      final t = i / stepCount;
      final mathX = spec.xMin + t * (spec.xMax - spec.xMin);
      final mathY = spec.f(mathX);

      final sx = toScreenX(mathX);
      final sy = toScreenY(mathY);

      if (firstPoint) {
        curvePath.moveTo(sx, sy);
        firstPoint = false;
      } else {
        curvePath.lineTo(sx, sy);
      }
    }
    canvas.drawPath(curvePath, curvePaint);

    // 4. Tracé de la tangente en pointillés oranges (y - y0 = slope * (x - x0))
    final tangentPaint = Paint()
      ..color = const Color(0xFFF97316) // Orange vif
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    // On calcule les points extrêmes de la tangente sur la largeur visible
    final tanX1 = spec.xMin;
    final tanY1 = pointY + slope * (tanX1 - pointX);
    final tanX2 = spec.xMax;
    final tanY2 = pointY + slope * (tanX2 - pointX);

    _drawDashedLine(
      canvas,
      Offset(toScreenX(tanX1), toScreenY(tanY1)),
      Offset(toScreenX(tanX2), toScreenY(tanY2)),
      tangentPaint,
      dashWidth: 6,
      dashSpace: 4,
    );

    // 5. Point A avec anneau d'accent
    final screenPointX = toScreenX(pointX);
    final screenPointY = toScreenY(pointY);

    // Halo extérieur
    canvas.drawCircle(
      Offset(screenPointX, screenPointY),
      8,
      Paint()..color = const Color(0xFFF97316).withAlpha(60),
    );

    // Point central A
    canvas.drawCircle(
      Offset(screenPointX, screenPointY),
      5.5,
      Paint()..color = const Color(0xFFEA580C),
    );

    canvas.drawCircle(
      Offset(screenPointX, screenPointY),
      5.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Label textuel 'A'
    _drawText(
      canvas,
      'A',
      Offset(screenPointX - 6, screenPointY - 24),
      const TextStyle(
        color: Color(0xFFC2410C),
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 3,
  }) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final double unitDx = dx / distance;
    final double unitDy = dy / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final double nextEnd = math.min(currentDistance + dashWidth, distance);
      canvas.drawLine(
        Offset(p1.dx + unitDx * currentDistance, p1.dy + unitDy * currentDistance),
        Offset(p1.dx + unitDx * nextEnd, p1.dy + unitDy * nextEnd),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.pointX != pointX ||
        oldDelegate.pointY != pointY ||
        oldDelegate.slope != slope;
  }
}

/// Boîte de dialogue modale haute-fidélité pour l'analyse graphique et formelle
class _FunctionGraphModalDialog extends StatefulWidget {
  final MathFunctionSpec spec;

  const _FunctionGraphModalDialog({required this.spec});

  @override
  State<_FunctionGraphModalDialog> createState() => _FunctionGraphModalDialogState();
}

class _FunctionGraphModalDialogState extends State<_FunctionGraphModalDialog> {
  int _activeTabIndex = 0; // 0: Graphe & Tangente, 1: Variations, 2: Solveur SymPy
  MathComputationResult? _solverResult;
  bool _isSolving = false;

  @override
  void initState() {
    super.initState();
    _loadExactAnalysis();
  }

  Future<void> _loadExactAnalysis() async {
    setState(() => _isSolving = true);
    final res = await ScientificToolsService.instance.solveEquation(
      widget.spec.formulaLatex,
      mode: 'solve',
    );
    if (mounted) {
      setState(() {
        _solverResult = res;
        _isSolving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        child: Column(
          children: [
            // En-tête avec titre, formule et fermeture
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.primaryCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.spec.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Tracé Déterministe & Calcul de Dérivée',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.primaryCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Encadré de la formule mathématique en KaTeX
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: MathFormulaView(
                formulaLatex: widget.spec.formulaLatex,
                fontSize: 14,
                label: 'FONCTION ÉTUDIÉE',
              ),
            ),

            // Sélecteur d'onglets (Graphe, Variations, Solveur)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab(0, 'Courbe & Tangente', Icons.timeline_rounded),
                    _buildTab(1, 'Variations', Icons.table_rows_rounded),
                    _buildTab(2, 'Solveur / Zéros', Icons.calculate_rounded),
                  ],
                ),
              ),
            ),

            // Corps du modal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildBodyContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryCyan : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_activeTabIndex) {
      case 0:
        return InteractiveFunctionGraph(
          functionSpec: widget.spec,
          initialX: (widget.spec.xMin + widget.spec.xMax) / 2,
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                'Étude du signe de f\'(x) et des variations de f(x) :',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const VariationTableInteractive(isInteractive: true),
          ],
        );
      case 2:
      default:
        if (_isSolving) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            ),
          );
        }
        final res = _solverResult;
        if (res == null) {
          return const Center(
            child: Text(
              'Analyse en cours...',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.tealSuccess.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.tealSuccess, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Résolution Exacte Déterministe',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tealSuccess,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MathFormulaView(
                    formulaLatex: res.latexResult,
                    fontSize: 15,
                    label: 'SOLUTIONS (RACINES / EXTREMA)',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    res.explanation,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0)),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}
