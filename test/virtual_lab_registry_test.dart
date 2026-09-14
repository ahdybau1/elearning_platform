import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/core/models/content_block.dart';
import 'package:student_app/core/rendering/block_renderer_registry.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/circuit_simulator_widget.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/ballistics_simulator_widget.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/molecular_viewer_3d_widget.dart';
import 'package:student_app/features/pedagogy/widgets/virtual_labs/python_sandbox_widget.dart';
import 'package:student_app/features/pedagogy/widgets/interactive_function_graph.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget(ContentBlock block) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => BlockRendererRegistry.build(context, block),
          ),
        ),
      ),
    );
  }

  group('BlockRendererRegistry Deterministic Virtual Labs Routing', () {
    testWidgets('renders SPICE circuit simulator block with correct badge and engine',
        (WidgetTester tester) async {
      final block = ContentBlock(
        type: 'virtual_lab',
        heading: 'Laboratoire Circuit RLC SPICE',
        body: 'Expérimentation oscillateur amorti.',
        metadata: const {'labType': 'circuit'},
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SPICE 3F5 DÉTERMINISTE'), findsOneWidget);
      expect(find.text('Laboratoire Circuit RLC SPICE'), findsOneWidget);
      expect(find.byType(CircuitSimulatorWidget), findsOneWidget);
      expect(find.byTooltip('Mode plein écran'), findsOneWidget);
      expect(find.byTooltip('Réduire'), findsOneWidget);
    });

    testWidgets('renders Ballistics simulator block with RK4 badge and engine',
        (WidgetTester tester) async {
      final block = ContentBlock(
        type: 'virtual_lab',
        heading: 'Laboratoire Mouvement Parabolique',
        body: 'Tir balistique avec gravité terrestre.',
        metadata: const {'labType': 'ballistics'},
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pumpAndSettle();

      expect(find.text('MOTEUR NEWTONIEN RK4'), findsOneWidget);
      expect(find.text('Laboratoire Mouvement Parabolique'), findsOneWidget);
      expect(find.byType(BallisticsSimulatorWidget), findsOneWidget);
    });

    testWidgets('renders Molecular 3D Viewer block with Covalent 3D badge and engine',
        (WidgetTester tester) async {
      final block = ContentBlock(
        type: 'virtual_lab',
        heading: 'Laboratoire Stéréochimie 3D',
        body: 'Visualisation des liaisons covalentes.',
        metadata: const {'labType': 'molecule'},
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pumpAndSettle();

      expect(find.text('GÉOMÉTRIE 3D COVALENTE'), findsOneWidget);
      expect(find.text('Laboratoire Stéréochimie 3D'), findsOneWidget);
      expect(find.byType(MolecularViewer3DWidget), findsOneWidget);
    });

    testWidgets('routes code_runner block type to Python Sandbox with Pyodide badge',
        (WidgetTester tester) async {
      final block = const ContentBlock(
        type: 'code_runner',
        heading: 'Atelier Algorithmique Python',
        body: 'def heron(n): ...',
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pumpAndSettle();

      expect(find.text('INTERPRÉTEUR PYODIDE WASM'), findsOneWidget);
      expect(find.text('Atelier Algorithmique Python'), findsOneWidget);
      expect(find.byType(PythonSandboxWidget), findsOneWidget);
    });

    testWidgets('routes graph_plot block type to InteractiveFunctionGraph with GraphEngine badge',
        (WidgetTester tester) async {
      final block = const ContentBlock(
        type: 'graph_plot',
        heading: 'Tracé f(x) = x^2 - 3x + 2',
        body: 'Courbe et tangente réactive.',
        metadata: {'expression': 'x^2 - 3*x + 2'},
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pumpAndSettle();

      expect(find.text('GRAPH ENGINE DÉTERMINISTE'), findsOneWidget);
      expect(find.text('Tracé f(x) = x^2 - 3x + 2'), findsOneWidget);
      expect(find.byType(InteractiveFunctionGraph), findsOneWidget);
    });

    testWidgets('collapses and expands virtual lab content on toggle tap',
        (WidgetTester tester) async {
      final block = ContentBlock(
        type: 'virtual_lab',
        heading: 'Test Pliage Lab',
        body: 'Test de l\'accordéon ergonomique mobile.',
        metadata: const {'labType': 'circuit'},
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pump(const Duration(milliseconds: 100));

      // Initialement déplié
      expect(find.byType(CircuitSimulatorWidget), findsOneWidget);
      expect(find.byTooltip('Réduire'), findsOneWidget);

      // Clic pour replier
      await tester.tap(find.byTooltip('Réduire'));
      await tester.pump(const Duration(milliseconds: 100));

      // Maintenant replié (simulateur masqué)
      expect(find.byType(CircuitSimulatorWidget), findsNothing);
      expect(find.byTooltip('Déplier'), findsOneWidget);

      // Clic pour redéplier
      await tester.tap(find.byTooltip('Déplier'));
      await tester.pump(const Duration(milliseconds: 100));

      // De nouveau affiché
      expect(find.byType(CircuitSimulatorWidget), findsOneWidget);
      expect(find.byTooltip('Réduire'), findsOneWidget);
    });
  });

  group('BlockRendererRegistry Media & Image Blocks Routing', () {
    testWidgets('renders image block with placeholder when url is empty', (tester) async {
      final block = const ContentBlock(
        type: 'image',
        heading: 'Schéma Fonctionnel',
        body: 'Figure explicative sans URL pour le moment.',
        metadata: {'caption': 'Légende de la figure'},
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pumpAndSettle();

      expect(find.text('Schéma Fonctionnel'), findsOneWidget);
      expect(find.text('Légende de la figure'), findsOneWidget);
      expect(find.text('Aucune ressource visuelle fournie'), findsOneWidget);
    });

    testWidgets('renders image block with URL and zoom button', (tester) async {
      final block = const ContentBlock(
        type: 'media_image',
        heading: 'Coupe Anatomique Oeil Humain',
        body: 'Schéma de l\'oeil avec cornée et rétine.',
        metadata: {
          'imageUrl': 'https://example.com/eye_anatomy.png',
          'caption': 'Figure 1 : Anatomie de l\'oeil',
          'altText': 'Schéma en coupe de l\'oeil humain',
        },
      );

      await tester.pumpWidget(createTestWidget(block));
      await tester.pump();

      expect(find.text('Coupe Anatomique Oeil Humain'), findsOneWidget);
      expect(find.text('Figure 1 : Anatomie de l\'oeil'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
    });
  });
}

