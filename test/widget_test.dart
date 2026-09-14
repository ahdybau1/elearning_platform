import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/core/rendering/math_formula_view.dart';
import 'package:student_app/core/rendering/latex_to_unicode_converter.dart';
import 'package:student_app/core/rendering/ai_message_bubble_renderer.dart';
import 'package:student_app/features/pedagogy/widgets/interactive_function_graph.dart';
import 'package:student_app/core/services/scientific_tools_service.dart';
import 'package:student_app/features/pedagogy/widgets/scientific_tools_modal.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/circuit_simulator_widget.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/molecular_viewer_3d_widget.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/python_sandbox_widget.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/ballistics_simulator_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MathFormulaView Student-Clean Rendering', () {
    testWidgets('renders formula view without technical badges and allows render switch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MathFormulaView(
              formulaLatex: r'f(x) = \frac{-b \pm \sqrt{\Delta}}{2a}',
              label: 'FORMULE QUADRATIQUE',
              showEngineToggle: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header label and student-friendly render mode
      expect(find.text('FORMULE QUADRATIQUE'), findsOneWidget);
      expect(find.text('Rendu vectoriel'), findsOneWidget);

      // Toggle render mode
      await tester.tap(find.text('Rendu vectoriel'));
      await tester.pumpAndSettle();

      expect(find.text('Rendu standard'), findsOneWidget);
    });

    testWidgets('renders piecewise cases environment without breaking lines',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MathFormulaView(
              formulaLatex: r'''\lim_{n \to +\infty} q^n = \begin{cases}
0 & \text{si } -1 < q < 1 \\
1 & \text{si } q = 1 \\
+\infty & \text{si } q > 1 \\
\text{Indéterminée (n'existe pas)} & \text{si } q \le -1
\end{cases}''',
              label: 'LIMITES SUITES',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // If MathFormulaView falls back to onErrorFallback, it renders SelectableText with raw "\begin{cases}"
      expect(find.textContaining(r'\begin{cases}'), findsNothing);
    });

    testWidgets('direct Math.tex with cases and aligned environments', (WidgetTester tester) async {
      String? caughtError;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Math.tex(
              r'''\lim_{n \to +\infty} q^n = \begin{cases}
0 & \text{si } -1 < q < 1 \\
1 & \text{si } q = 1 \\
+\infty & \text{si } q > 1 \\
\text{Indéterminée (n'existe pas)} & \text{si } q \le -1
\end{cases}''',
              onErrorFallback: (err) {
                caughtError = err.message;
                return Text('ERROR: ${err.message}');
              },
            ),
          ),
        ),
      );
      expect(caughtError, isNull);

      String? caughtAlignedError;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Math.tex(
              r'''\begin{aligned} A &= 1 \\ B &= 2 \end{aligned}''',
              onErrorFallback: (err) {
                caughtAlignedError = err.message;
                return Text('ALIGNED_ERROR: ${err.message}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(caughtAlignedError, isNull);
    });
  });

  group('ScientificToolsModal Integration', () {
    testWidgets('opens modal and displays all 3 scientific tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScientificToolsModal(
              initialQuery: 'x^2 - 5x + 6 = 0',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the 3 tabs defined in the specification
      expect(find.text('Calcul SymPy'), findsOneWidget);
      expect(find.text('Grapheur & Dérivée'), findsOneWidget);
      expect(find.text('Labos Virtuels'), findsOneWidget);
    });
  });

  group('ScientificToolsService Deterministic Math Engine', () {
    test('solves quadratic equation with real roots correctly', () async {
      final res = await ScientificToolsService.instance.solveEquation(
        'x^2 - 5x + 6 = 0',
        mode: 'solve',
      );

      expect(res.isSuccess, isTrue);
      expect(res.results, containsAll(['2', '3']));
      expect(res.latexResult, contains('x_1 = 2'));
      expect(res.latexResult, contains('x_2 = 3'));
    });

    test('computes cubic derivative analytically without hallucinations', () async {
      final res = await ScientificToolsService.instance.solveEquation(
        'x^3 - 3x^2 + 1',
        mode: 'derivative',
      );

      expect(res.isSuccess, isTrue);
      expect(res.latexResult, contains("f'(x) = 3x^2 - 6x"));
    });
  });

  group('MathRendererSettings Dual Engine', () {
    test('toggles between render engines smoothly', () {
      final notifier = MathRendererSettings.currentEngine;
      final initial = notifier.value;

      MathRendererSettings.toggleEngine();
      expect(notifier.value, isNot(initial));

      MathRendererSettings.toggleEngine();
      expect(notifier.value, equals(initial));
    });
  });

  group('LatexToUnicodeConverter (Zero Code Leakage)', () {
    test('converts piecewise cases, limits, and Greek symbols into clean text', () {
      const raw = r'''\lim_{n \to +\infty} q^n = \begin{cases}
0 & \text{si } -1 < q < 1 \\
1 & \text{si } q = 1 \\
+\infty & \text{si } q > 1 \\
\text{Indéterminée} & \text{si } q \le -1
\end{cases}''';

      final clean = LatexToUnicodeConverter.convert(raw);

      // Verify NO backslash or TeX commands remain
      expect(clean.contains(r'\lim'), isFalse);
      expect(clean.contains(r'\to'), isFalse);
      expect(clean.contains(r'\infty'), isFalse);
      expect(clean.contains(r'\begin'), isFalse);
      expect(clean.contains(r'\cases'), isFalse);
      expect(clean.contains(r'\text'), isFalse);
      expect(clean.contains(r'\le'), isFalse);

      // Verify converted mathematical symbols
      expect(clean, contains('lim'));
      expect(clean, contains('→'));
      expect(clean, contains('∞'));
      expect(clean, contains('≤'));
    });

    test('converts quadratic formulas and discriminant', () {
      const raw = r'\Delta = b^2 - 4ac';
      final clean = LatexToUnicodeConverter.convert(raw);
      expect(clean, equals('Δ = b² - 4ac'));
    });

    test('converts fractions into readable slash format', () {
      const raw = r'\frac{4 - 8}{4} = -1';
      final clean = LatexToUnicodeConverter.convert(raw);
      expect(clean, equals('(4 - 8) / 4 = -1'));
    });
  });

  group('MathFunctionSpec Dynamic Polynomial Parsing & Calculus', () {
    test('accurately parses 2x^2 - 4x - 6 quadratic polynomial', () {
      final spec = MathFunctionSpec.fromExpression('2x^2 - 4x - 6');

      expect(spec.isPolynomial, isTrue);
      expect(spec.expression, equals('2x² - 4x - 6'));
      expect(spec.derivativeExpression, equals("f'(x) = 4x - 4"));

      // Vertex of 2x^2 - 4x - 6 is x = -b/(2a) = 4/4 = 1, y = 2(1) - 4(1) - 6 = -8
      expect(spec.vertexX, equals(1.0));
      expect(spec.vertexY, equals(-8.0));

      // Roots of 2x^2 - 4x - 6: Δ = 16 - 4(2)(-6) = 64. x = (4 ± 8)/4 -> -1 and 3
      expect(spec.roots, containsAll([-1.0, 3.0]));

      // Function evaluations
      expect(spec.evaluate(0), equals(-6.0));
      expect(spec.evaluate(1), equals(-8.0));
      expect(spec.evaluate(-1), equals(0.0));
      expect(spec.evaluate(3), equals(0.0));

      // Analytical derivative evaluations
      expect(spec.evaluateDerivative(1), equals(0.0)); // Tangent is horizontal at vertex
      expect(spec.evaluateDerivative(0), equals(-4.0));
      expect(spec.evaluateDerivative(2), equals(4.0));
    });

    test('accurately computes tangent line equation at chosen point', () {
      final spec = MathFunctionSpec.fromExpression('2x^2 - 4x - 6');
      final tangentAtZero = spec.tangentLine(0);

      // At x=0, y=-6, f'(0) = -4 -> T: y = -4(x - 0) + (-6) = -4x - 6
      expect(tangentAtZero.slope, equals(-4.0));
      expect(tangentAtZero.yIntercept, equals(-6.0));
      expect(tangentAtZero.formulaText, contains('-4x - 6'));
    });
  });

  group('AiMessageBubbleRenderer Interactive Polynomial Features', () {
    testWidgets('renders message and detects polynomial action ribbon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AiMessageBubbleRenderer(
                message:
                    r"Voici l'étude du polynôme $P(x) = 2x^2 - 4x - 6$ avec $\Delta = 64$.",
                isAi: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no raw code leaks
      expect(find.textContaining(r'\Delta'), findsNothing);

      // Verify action ribbon with interactive curve buttons
      expect(find.text('Tracer la courbe & tangente'), findsOneWidget);
      expect(find.text('Calculer avec SymPy'), findsOneWidget);
    });
  });

  group('Interactive Virtual Labs (No Mocks)', () {
    testWidgets('CircuitSimulatorWidget renders and allows charge/discharge switching', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: CircuitSimulatorWidget()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CIRCUIT RC EN TEMPS RÉEL'), findsOneWidget);
      expect(find.text('Lancer Charge (E)'), findsOneWidget);
      expect(find.text('Lancer Décharge'), findsOneWidget);
      await tester.tap(find.text('Lancer Décharge'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('DÉCHARGE'), findsWidgets);
    });

    testWidgets('MolecularViewer3DWidget renders official molecules', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: MolecularViewer3DWidget()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CHIMIE & STÉRÉOCHIMIE 3D'), findsOneWidget);
      expect(find.text('Méthane'), findsOneWidget);
      expect(find.text('Tétraédrique'), findsOneWidget);
    });

    testWidgets('PythonSandboxWidget executes preset algorithm', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: PythonSandboxWidget()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bac à Sable Python (WASM)'), findsOneWidget);
      expect(find.text('Exécuter'), findsOneWidget);
      await tester.tap(find.text('Exécuter'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Python 3.12'), findsWidgets);
    });

    testWidgets('BallisticsSimulatorWidget computes trajectory parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: BallisticsSimulatorWidget()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MÉCANIQUE NEWTONIENNE'), findsOneWidget);
      expect(find.text('Tirer !'), findsOneWidget);
      expect(find.textContaining('Portée Maximale'), findsOneWidget);
      expect(find.textContaining('Flèche'), findsOneWidget);
    });
  });
}
