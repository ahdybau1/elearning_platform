import 'dart:math' as math;

/// Modèle d'analyse polynomiale exacte
class PolynomialAnalysisResult {
  final double a;
  final double b;
  final double c;
  final double discriminant;
  final List<double> realRoots;
  final (double x, double y) vertex;
  final String derivativeLatex;
  final String tangentEquationAt1;

  const PolynomialAnalysisResult({
    required this.a,
    required this.b,
    required this.c,
    required this.discriminant,
    required this.realRoots,
    required this.vertex,
    required this.derivativeLatex,
    required this.tangentEquationAt1,
  });
}

/// Moteur Mathématique Déterministe d'ELEF (Calcul exact sans hallucination LLM)
class MathEngine {
  MathEngine._();

  /// Analyse un trinôme du second degré P(x) = ax² + bx + c
  static PolynomialAnalysisResult analyzeQuadratic({
    required double a,
    required double b,
    required double c,
  }) {
    final delta = (b * b) - (4 * a * c);
    final List<double> roots = [];

    if (delta > 0) {
      final sqrtDelta = math.sqrt(delta);
      roots.add((-b - sqrtDelta) / (2 * a));
      roots.add((-b + sqrtDelta) / (2 * a));
      roots.sort();
    } else if (delta == 0) {
      roots.add(-b / (2 * a));
    }

    final vx = -b / (2 * a);
    final vy = (a * vx * vx) + (b * vx) + c;

    // Dérivée f'(x) = 2ax + b
    final da = 2 * a;
    final derivativeStr = b >= 0 ? '${da.toStringAsFixed(0)}x + ${b.toStringAsFixed(0)}' : '${da.toStringAsFixed(0)}x - ${(-b).toStringAsFixed(0)}';

    // Tangente en x0 = 1
    const x0 = 1.0;
    final y0 = a * (x0 * x0) + b * x0 + c;
    final slope = 2 * a * x0 + b;
    final intercept = y0 - slope * x0;
    final tangentStr = intercept >= 0
        ? 'y = ${slope.toStringAsFixed(1)}x + ${intercept.toStringAsFixed(1)}'
        : 'y = ${slope.toStringAsFixed(1)}x - ${(-intercept).toStringAsFixed(1)}';

    return PolynomialAnalysisResult(
      a: a,
      b: b,
      c: c,
      discriminant: delta,
      realRoots: roots,
      vertex: (vx, vy),
      derivativeLatex: derivativeStr,
      tangentEquationAt1: tangentStr,
    );
  }

  /// Normalisation de code LaTeX pour éliminer les scories
  static String cleanLatex(String input) {
    var s = input.trim();
    if (s.startsWith(r'$$') && s.endsWith(r'$$')) {
      s = s.substring(2, s.length - 2).trim();
    } else if (s.startsWith(r'$') && s.endsWith(r'$')) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }
}
