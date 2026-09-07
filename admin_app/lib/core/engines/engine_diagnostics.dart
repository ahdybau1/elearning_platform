import 'capability_registry.dart';
import 'math_engine.dart';
import 'graph_engine.dart';
import 'simulation_engine.dart';

class EngineDiagnostic {
  final bool checked;
  final bool passed;
  final String detail;
  const EngineDiagnostic({
    required this.checked,
    required this.passed,
    required this.detail,
  });
}

/// Contrôles locaux explicites. Aucun résultat ne certifie un service distant.
class EngineDiagnostics {
  static EngineDiagnostic run(CapabilityType type) {
    bool passed;
    String detail;
    try {
      switch (type) {
        case CapabilityType.latex:
          passed = MathEngine.cleanLatex(r'$$x^2$$') == 'x^2';
          detail =
              'Normalisation locale LaTeX vérifiée ; rendu visuel non testé ici.';
        case CapabilityType.plot2d:
          final result = MathEngine.analyzeQuadratic(a: 1, b: -3, c: 2);
          final spec = GraphEngine.defaultQuadratic();
          passed =
              result.realRoots.length == 2 &&
              result.realRoots[0] == 1 &&
              result.realRoots[1] == 2 &&
              GraphCurveSpec.fromJson(spec.toJson()).expression ==
                  spec.expression;
          detail =
              'Calcul des racines de x² − 3x + 2 et configuration du graphe vérifiés ; rendu non testé ici.';
        case CapabilityType.physicsSimulation:
        case CapabilityType.circuitSimulation:
        case CapabilityType.molecular3d:
          final spec = switch (type) {
            CapabilityType.physicsSimulation =>
              SimulationEngine.ballisticsPreset(),
            CapabilityType.circuitSimulation => SimulationEngine.rlcPreset(),
            _ => SimulationEngine.molecularPreset(),
          };
          passed =
              SimulationSpec.fromJson(spec.toJson()).type == spec.type &&
              spec.initialParameters.isNotEmpty;
          detail =
              'Lecture du preset local vérifiée. Le simulateur et sa précision ne sont pas testés ici.';
        default:
          return const EngineDiagnostic(
            checked: false,
            passed: false,
            detail:
                'Aucun diagnostic d’exécution raccordé. Disponibilité non vérifiée.',
          );
      }
      return EngineDiagnostic(
        checked: true,
        passed: passed,
        detail: passed ? detail : 'Le contrôle local a échoué.',
      );
    } catch (_) {
      return const EngineDiagnostic(
        checked: true,
        passed: false,
        detail: 'Le contrôle local a échoué.',
      );
    }
  }
}
