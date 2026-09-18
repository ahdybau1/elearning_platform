import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';

/// Point clé du tableau de variations pour les bornes et extrema
class VariationPoint {
  final String xLatex; // ex: '-\\infty', '1', '+\\infty'
  final String yLatex; // ex: '+\\infty', '-8', '+\\infty'
  final bool isHigh; // true si placé en haut de la case f(x), false si placé en bas
  final bool isZeroDerivative; // true si f'(x) = 0 à ce point
  final bool isForbiddenValue; // true si valeur interdite (double barre)

  const VariationPoint({
    required this.xLatex,
    required this.yLatex,
    required this.isHigh,
    this.isZeroDerivative = false,
    this.isForbiddenValue = false,
  });
}

/// Intervalle de variation entre deux points
class VariationInterval {
  final String sign; // '+', '-', ou ''
  final bool isIncreasing; // true: flèche montante, false: flèche descendante

  const VariationInterval({
    required this.sign,
    required this.isIncreasing,
  });
}

/// Données structurées complètes pour un tableau de variations officiel
class AcademicVariationData {
  final List<VariationPoint> points; // N points (au moins 2)
  final List<VariationInterval> intervals; // N - 1 intervalles

  const AcademicVariationData({
    required this.points,
    required this.intervals,
  });

  /// Construit les données pour un polynôme quadratique f(x) = ax^2 + bx + c
  factory AcademicVariationData.fromQuadratic({
    required double a,
    required double b,
    required double c,
    required double vertexX,
    required double vertexY,
  }) {
    final isFacingUp = a > 0;
    final vxStr = vertexX.toStringAsFixed(vertexX.truncateToDouble() == vertexX ? 0 : 1);
    final vyStr = vertexY.toStringAsFixed(vertexY.truncateToDouble() == vertexY ? 0 : 1);

    if (isFacingUp) {
      // a > 0 : décroissante sur ]-inf, vx[ puis croissante sur ]vx, +inf[
      // Sommet = minimum
      return AcademicVariationData(
        points: [
          const VariationPoint(xLatex: r'-\infty', yLatex: r'+\infty', isHigh: true),
          VariationPoint(xLatex: vxStr, yLatex: vyStr, isHigh: false, isZeroDerivative: true),
          const VariationPoint(xLatex: r'+\infty', yLatex: r'+\infty', isHigh: true),
        ],
        intervals: const [
          VariationInterval(sign: '-', isIncreasing: false),
          VariationInterval(sign: '+', isIncreasing: true),
        ],
      );
    } else {
      // a < 0 : croissante sur ]-inf, vx[ puis décroissante sur ]vx, +inf[
      // Sommet = maximum
      return AcademicVariationData(
        points: [
          const VariationPoint(xLatex: r'-\infty', yLatex: r'-\infty', isHigh: false),
          VariationPoint(xLatex: vxStr, yLatex: vyStr, isHigh: true, isZeroDerivative: true),
          const VariationPoint(xLatex: r'+\infty', yLatex: r'-\infty', isHigh: false),
        ],
        intervals: const [
          VariationInterval(sign: '+', isIncreasing: true),
          VariationInterval(sign: '-', isIncreasing: false),
        ],
      );
    }
  }

  /// Construit les données pour une cubique type f(x) = x^3 - 3x^2 + 1
  factory AcademicVariationData.fromCubicStandard() {
    return const AcademicVariationData(
      points: [
        VariationPoint(xLatex: r'-\infty', yLatex: r'-\infty', isHigh: false),
        VariationPoint(xLatex: '0', yLatex: '1', isHigh: true, isZeroDerivative: true),
        VariationPoint(xLatex: '2', yLatex: '-3', isHigh: false, isZeroDerivative: true),
        VariationPoint(xLatex: r'+\infty', yLatex: r'+\infty', isHigh: true),
      ],
      intervals: [
        VariationInterval(sign: '+', isIncreasing: true),
        VariationInterval(sign: '-', isIncreasing: false),
        VariationInterval(sign: '+', isIncreasing: true),
      ],
    );
  }

  /// Construit les données pour une fonction affine f(x) = ax + b
  factory AcademicVariationData.fromAffine({required double a, required double b}) {
    final isIncreasing = a >= 0;
    return AcademicVariationData(
      points: [
        VariationPoint(
          xLatex: r'-\infty',
          yLatex: isIncreasing ? r'-\infty' : r'+\infty',
          isHigh: !isIncreasing,
        ),
        VariationPoint(
          xLatex: r'+\infty',
          yLatex: isIncreasing ? r'+\infty' : r'-\infty',
          isHigh: isIncreasing,
        ),
      ],
      intervals: [
        VariationInterval(sign: isIncreasing ? '+' : '-', isIncreasing: isIncreasing),
      ],
    );
  }
}

/// Widget affichant un Tableau de Variations selon les standards officiels de l'Éducation Nationale
class AcademicVariationTableView extends StatelessWidget {
  final AcademicVariationData data;
  final String title;

  const AcademicVariationTableView({
    super.key,
    required this.data,
    this.title = 'Tableau de variations officiel',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0D1527) : Colors.white;
    final borderColor = isDark ? const Color(0xFF38BDF8).withAlpha(90) : const Color(0xFF0284C7);
    final headerColBg = isDark ? const Color(0xFF131D36) : const Color(0xFFF1F5F9);

    const double colHeaderWidth = 90.0;
    const double rowXHeight = 44.0;
    const double rowDerivHeight = 44.0;
    const double rowFHeight = 110.0;
    const double totalHeight = rowXHeight + rowDerivHeight + rowFHeight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bandeau supérieur informatif
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withAlpha(25),
              border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, size: 16, color: AppColors.primaryCyan),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryCyan,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Grille du tableau (scrollable horizontalement si petit écran)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: totalHeight,
              child: Row(
                children: [
                  // Colonne d'en-tête gauche fixe (x, f'(x), f(x))
                  Container(
                    width: colHeaderWidth,
                    height: totalHeight,
                    decoration: BoxDecoration(
                      color: headerColBg,
                      border: Border(right: BorderSide(color: borderColor, width: 1.4)),
                    ),
                    child: Column(
                      children: [
                        _buildHeaderCell('x', height: rowXHeight, borderColor: borderColor, isMath: true),
                        _buildHeaderCell("f'(x)", height: rowDerivHeight, borderColor: borderColor, isMath: true),
                        _buildHeaderCell('Variations\nde f', height: rowFHeight, borderColor: borderColor, isSmall: true),
                      ],
                    ),
                  ),

                  // Corps vectoriel du tableau de variation
                  CustomPaint(
                    size: Size(math.max(340.0, data.points.length * 110.0), totalHeight),
                    painter: _AcademicVariationPainter(
                      data: data,
                      rowXHeight: rowXHeight,
                      rowDerivHeight: rowDerivHeight,
                      rowFHeight: rowFHeight,
                      borderColor: borderColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    required double height,
    required Color borderColor,
    bool isMath = false,
    bool isSmall = false,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: isMath
          ? Math.tex(
              label,
              mathStyle: MathStyle.text,
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            )
          : Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmall ? 11.5 : 13,
                height: 1.2,
              ),
            ),
    );
  }
}

/// CustomPainter traçant avec précision les colonnes, signes, zéros barrés et flèches obliques
class _AcademicVariationPainter extends CustomPainter {
  final AcademicVariationData data;
  final double rowXHeight;
  final double rowDerivHeight;
  final double rowFHeight;
  final Color borderColor;
  final bool isDark;

  _AcademicVariationPainter({
    required this.data,
    required this.rowXHeight,
    required this.rowDerivHeight,
    required this.rowFHeight,
    required this.borderColor,
    required this.isDark,
  });

  static String _formatVariationMath(String raw) {
    var s = raw.trim();
    s = s.replaceAll(r'-\infty', '−∞');
    s = s.replaceAll(r'+\infty', '+∞');
    s = s.replaceAll(r'\infty', '∞');
    s = s.replaceAll('-infty', '−∞');
    s = s.replaceAll('+infty', '+∞');
    s = s.replaceAll('infty', '∞');
    s = s.replaceAll(r'\frac{1}{2}', '½');
    s = s.replaceAll(r'\frac{1}{3}', '⅓');
    s = s.replaceAll(r'\frac{1}{4}', '¼');
    s = s.replaceAll(r'\frac{3}{4}', '¾');
    s = s.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '${m.group(1)}/${m.group(2)}');
    s = s.replaceAll(r'\sqrt', '√');
    s = s.replaceAll(r'\', '');
    s = s.replaceAll(r'$', '');
    return s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final numPoints = data.points.length;
    if (numPoints < 2) return;

    final linePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = AppColors.primaryCyan
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 1. Lignes horizontales séparatrices
    canvas.drawLine(Offset(0, rowXHeight), Offset(size.width, rowXHeight), linePaint);
    canvas.drawLine(
      Offset(0, rowXHeight + rowDerivHeight),
      Offset(size.width, rowXHeight + rowDerivHeight),
      linePaint,
    );

    // Calcul des abscisses X des points clés
    // Marge gauche/droite pour que les valeurs -inf et +inf ne soient pas collées aux bords
    const double paddingX = 40.0;
    final double usableWidth = size.width - 2 * paddingX;
    final double stepX = usableWidth / (numPoints - 1);

    final List<double> pointXList = [];
    for (int i = 0; i < numPoints; i++) {
      pointXList.add(paddingX + i * stepX);
    }

    // 2. Ligne 1 : Tracé des valeurs de x
    for (int i = 0; i < numPoints; i++) {
      final px = pointXList[i];
      final pt = data.points[i];
      _drawCenteredText(
        canvas,
        _formatVariationMath(pt.xLatex),
        Offset(px, rowXHeight / 2),
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14.0,
          fontFamily: 'serif',
        ),
      );
    }

    // 3. Ligne 2 : Signes de f'(x) et zéros avec barre verticale
    final double yDerivMiddle = rowXHeight + rowDerivHeight / 2;

    // Valeurs critiques : zéro barré ou double barre
    for (int i = 0; i < numPoints; i++) {
      final px = pointXList[i];
      final pt = data.points[i];

      if (pt.isForbiddenValue) {
        // Double barre verticale (valeur interdite) traversant lignes 2 et 3
        const double dGap = 3.0;
        final forbidPaint = Paint()
          ..color = const Color(0xFFEF4444)
          ..strokeWidth = 1.4;
        canvas.drawLine(Offset(px - dGap, rowXHeight), Offset(px - dGap, size.height), forbidPaint);
        canvas.drawLine(Offset(px + dGap, rowXHeight), Offset(px + dGap, size.height), forbidPaint);
      } else if (pt.isZeroDerivative) {
        // Barre verticale locale traversant la ligne f'(x)
        final tickPaint = Paint()
          ..color = borderColor.withAlpha(150)
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(px, rowXHeight + 4),
          Offset(px, rowXHeight + rowDerivHeight - 4),
          tickPaint,
        );

        // Petit cercle ou zéro centré
        _drawCenteredText(
          canvas,
          '0',
          Offset(px, yDerivMiddle),
          const TextStyle(
            color: Color(0xFFF59E0B), // Ambre
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          hasBackground: true,
          bgColor: isDark ? const Color(0xFF0D1527) : Colors.white,
        );
      }
    }

    // Signes dans chaque intervalle (+ ou -)
    for (int i = 0; i < data.intervals.length; i++) {
      final x1 = pointXList[i];
      final x2 = pointXList[i + 1];
      final midX = (x1 + x2) / 2;
      final interval = data.intervals[i];

      _drawCenteredText(
        canvas,
        interval.sign,
        Offset(midX, yDerivMiddle),
        TextStyle(
          color: interval.sign == '+'
              ? const Color(0xFF10B981) // Vert
              : const Color(0xFFEF4444), // Rouge
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    // 4. Ligne 3 : Variations de f(x) (Flèches diagonales et valeurs haute/basse)
    final double fTopY = rowXHeight + rowDerivHeight + 18.0;
    final double fBottomY = size.height - 22.0;

    // Tracé des valeurs f aux bornes / extrema
    for (int i = 0; i < numPoints; i++) {
      final px = pointXList[i];
      final pt = data.points[i];
      final double py = pt.isHigh ? fTopY : fBottomY;

      _drawCenteredText(
        canvas,
        _formatVariationMath(pt.yLatex),
        Offset(px, py),
        TextStyle(
          color: pt.isHigh ? const Color(0xFF38BDF8) : const Color(0xFFA78BFA),
          fontWeight: FontWeight.bold,
          fontSize: 14.0,
          fontFamily: 'serif',
        ),
      );
    }

    // Tracé des flèches obliques/diagonales reliant chaque intervalle
    for (int i = 0; i < data.intervals.length; i++) {
      final pt1 = data.points[i];
      final pt2 = data.points[i + 1];
      final x1 = pointXList[i] + 16.0;
      final x2 = pointXList[i + 1] - 16.0;

      final double y1 = pt1.isHigh ? (fTopY + 12.0) : (fBottomY - 12.0);
      final double y2 = pt2.isHigh ? (fTopY + 12.0) : (fBottomY - 12.0);

      // Tracé de la flèche diagonale
      _drawDiagonalArrow(canvas, Offset(x1, y1), Offset(x2, y2), arrowPaint);
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    bool hasBackground = false,
    Color? bgColor,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();

    final offset = Offset(center.dx - tp.width / 2, center.dy - tp.height / 2);

    if (hasBackground && bgColor != null) {
      final bgRect = Rect.fromCenter(
        center: center,
        width: tp.width + 6,
        height: tp.height + 4,
      );
      canvas.drawRect(bgRect, Paint()..color = bgColor);
    }

    tp.paint(canvas, offset);
  }

  void _drawDiagonalArrow(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    canvas.drawLine(p1, p2, paint);

    // Tête de flèche
    final double angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    const double arrowHeadLength = 10.0;
    const double arrowHeadAngle = 0.45; // ~26 degrés

    final xHead1 = p2.dx - arrowHeadLength * math.cos(angle - arrowHeadAngle);
    final yHead1 = p2.dy - arrowHeadLength * math.sin(angle - arrowHeadAngle);
    final xHead2 = p2.dx - arrowHeadLength * math.cos(angle + arrowHeadAngle);
    final yHead2 = p2.dy - arrowHeadLength * math.sin(angle + arrowHeadAngle);

    final path = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(xHead1, yHead1)
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(xHead2, yHead2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AcademicVariationPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.borderColor != borderColor;
  }
}
