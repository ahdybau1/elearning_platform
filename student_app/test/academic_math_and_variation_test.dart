import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/features/pedagogy/widgets/academic_variation_table_view.dart';
import 'package:student_app/features/pedagogy/widgets/function_study_modal.dart';
import 'package:student_app/features/pedagogy/widgets/interactive_function_graph.dart';
import 'package:student_app/features/pedagogy/widgets/scientific_tools_modal.dart';

void main() {
  group('Academic Variation Table Structure & Logic', () {
    test('fromQuadratic generates academic columns for 2x^2 - 4x - 6', () {
      final data = AcademicVariationData.fromQuadratic(
        a: 2.0,
        b: -4.0,
        c: -6.0,
        vertexX: 1.0,
        vertexY: -8.0,
      );

      // Verify domain and vertex points
      expect(data.points.length, equals(3));
      expect(data.points[0].xLatex, equals(r'-\infty'));
      expect(data.points[1].xLatex, equals('1'));
      expect(data.points[2].xLatex, equals(r'+\infty'));

      // Derivative signs and zeroes
      expect(data.intervals.length, equals(2));
      expect(data.intervals[0].sign, equals('-'));
      expect(data.intervals[0].isIncreasing, isFalse);
      expect(data.points[1].isZeroDerivative, isTrue);
      expect(data.intervals[1].sign, equals('+'));
      expect(data.intervals[1].isIncreasing, isTrue);

      // Variation curve: descends to -8 then ascends
      expect(data.points[0].isHigh, isTrue);
      expect(data.points[0].yLatex, equals(r'+\infty'));
      expect(data.points[1].isHigh, isFalse);
      expect(data.points[1].yLatex, equals('-8'));
      expect(data.points[2].isHigh, isTrue);
      expect(data.points[2].yLatex, equals(r'+\infty'));
    });

    test('fromQuadratic generates inverted variations for -x^2 + 2x + 3', () {
      final data = AcademicVariationData.fromQuadratic(
        a: -1.0,
        b: 2.0,
        c: 3.0,
        vertexX: 1.0,
        vertexY: 4.0,
      );

      // Derivative sign row: a < 0 -> positive then 0 then negative
      expect(data.intervals[0].sign, equals('+'));
      expect(data.intervals[0].isIncreasing, isTrue);
      expect(data.points[1].isZeroDerivative, isTrue);
      expect(data.intervals[1].sign, equals('-'));
      expect(data.intervals[1].isIncreasing, isFalse);

      // Variation curve: ascends to vertex 4 (high) then descends to -infty
      expect(data.points[0].isHigh, isFalse);
      expect(data.points[1].isHigh, isTrue);
      expect(data.points[1].yLatex, equals('4'));
      expect(data.points[2].isHigh, isFalse);
    });

    test('fromCubicStandard generates 4 columns with two horizontal tangents', () {
      final data = AcademicVariationData.fromCubicStandard();

      expect(data.points.length, equals(4));
      expect(data.points[1].xLatex, equals('0'));
      expect(data.points[2].xLatex, equals('2'));

      // Two zeroes for the derivative
      final zeroes = data.points.where((p) => p.isZeroDerivative).toList();
      expect(zeroes.length, equals(2));
    });

    testWidgets('AcademicVariationTableView renders custom painter table cleanly', (tester) async {
      final academicData = AcademicVariationData.fromQuadratic(
        a: 1.0,
        b: -4.0,
        c: 3.0,
        vertexX: 2.0,
        vertexY: -1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: AcademicVariationTableView(data: academicData),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AcademicVariationTableView), findsOneWidget);
    });
  });

  group('FunctionStudyData Rigor & Detailed Step-by-Step Breakdown', () {
    test('generates complete Baccalaureate-grade demonstration for 2x^2 - 4x - 6', () {
      final study = FunctionStudyData.fromExpression('2x^2 - 4x - 6');

      // 1. Definition domain steps
      expect(study.domainSteps.length, greaterThanOrEqualTo(3));
      expect(study.domainSteps.first, contains('polynôme'));

      // 2. Limits at infinity with factorisation and product limit theorem
      expect(study.limitMinusInfSteps.length, greaterThanOrEqualTo(3));
      expect(
        study.limitMinusInfSteps.any((s) => s.contains('monôme') || s.contains('terme prépondérant')),
        isTrue,
      );
      expect(study.limitMinusInfSteps.any((s) => s.contains('produit')), isTrue);

      expect(study.limitPlusInfSteps.length, greaterThanOrEqualTo(3));

      // 3. Detailed derivative steps
      expect(study.derivativeSteps.any((s) => s.contains(r"(x^n)' = n x^{n-1}")), isTrue);
      expect(study.derivativeSteps.any((s) => s.contains("f'(x) = 4x - 4")), isTrue);

      // 4. Critical points & vertex with horizontal tangent
      expect(study.vertexSteps.any((s) => s.contains(r'-\frac{b}{2a}')), isTrue);
      expect(study.vertexSteps.any((s) => s.contains('tangente horizontale')), isTrue);

      // 5. Discriminant Delta = b^2 - 4ac with value substitutions
      expect(study.rootsSteps.any((s) => s.contains(r'\Delta = b^2 - 4ac')), isTrue);
      expect(study.rootsSteps.any((s) => s.contains(r'\Delta > 0')), isTrue);
      expect(study.rootsSteps.any((s) => s.contains(r'x_1 =') || s.contains(r'x_2 =')), isTrue);

      // 6. y-intercept
      expect(study.yInterceptSteps.any((s) => s.contains('f(0)')), isTrue);
      expect(study.yInterceptLatex, equals('f(0) = -6'));
    });

    testWidgets('FunctionStudyModal renders official variation table and detailed steps', (tester) async {
      final studyData = FunctionStudyData.fromExpression('2x^2 - 4x - 6');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: FunctionStudyModal(data: studyData),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and sections
      expect(find.textContaining('ÉTUDE COMPLÈTE DE LA FONCTION'), findsOneWidget);
      expect(find.text('5. Tableau de Variations Officiel'), findsOneWidget);
      expect(find.byType(AcademicVariationTableView), findsOneWidget);
    });
  });

  group('InteractiveFunctionGraph Controls & Graduation', () {
    testWidgets('renders function graph with Y-axis controls and responsive scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                height: 900,
                width: 800,
                child: InteractiveFunctionGraph(
                  functionSpec: MathFunctionSpec.fromExpression('x^2 - 4'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Y-axis control chips
      expect(find.text('Y +'), findsOneWidget);
      expect(find.text('Y -'), findsOneWidget);
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.textContaining('Axe Y : ['), findsOneWidget);
    });
  });

  group('ScientificToolsModal Live Preview', () {
    testWidgets('renders formula live preview container and example chips with math', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ScientificToolsModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and actions
      expect(find.text('ATELIER DE CALCUL & OUTILS SCIENTIFIQUES'), findsOneWidget);
      expect(find.text('EXPRESSION MATHÉMATIQUE'), findsOneWidget);
      expect(find.text('Résoudre = 0'), findsOneWidget);
      expect(find.text('Calculer Dérivée'), findsOneWidget);
    });
  });
}
