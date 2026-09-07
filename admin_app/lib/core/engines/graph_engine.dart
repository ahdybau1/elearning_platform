/// Spécification de fonction pour le moteur de tracé 2D
class GraphCurveSpec {
  final String expression;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double? initialTangentX;
  final String? label;

  const GraphCurveSpec({
    required this.expression,
    this.xMin = -5.0,
    this.xMax = 5.0,
    this.yMin = -10.0,
    this.yMax = 10.0,
    this.initialTangentX = 1.0,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'expression': expression,
    'x_min': xMin,
    'x_max': xMax,
    'y_min': yMin,
    'y_max': yMax,
    'initial_tangent_x': initialTangentX,
    if (label != null) 'label': label,
  };

  factory GraphCurveSpec.fromJson(Map<String, dynamic> json) {
    return GraphCurveSpec(
      expression: json['expression'] as String? ?? 'x^2 - 4',
      xMin: (json['x_min'] as num?)?.toDouble() ?? -5.0,
      xMax: (json['x_max'] as num?)?.toDouble() ?? 5.0,
      yMin: (json['y_min'] as num?)?.toDouble() ?? -10.0,
      yMax: (json['y_max'] as num?)?.toDouble() ?? 10.0,
      initialTangentX: (json['initial_tangent_x'] as num?)?.toDouble() ?? 1.0,
      label: json['label'] as String?,
    );
  }
}

/// Moteur de configuration et de rendu de graphiques fonctionnels 2D
class GraphEngine {
  GraphEngine._();

  static GraphCurveSpec defaultQuadratic() {
    return const GraphCurveSpec(
      expression: '2x^2 - 4x - 6',
      xMin: -4.0,
      xMax: 6.0,
      yMin: -12.0,
      yMax: 12.0,
      initialTangentX: 2.0,
      label: 'Parabole f(x) = 2x² - 4x - 6',
    );
  }
}
