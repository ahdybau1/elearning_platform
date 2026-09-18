import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_app/core/models/academic_node.dart';
import 'package:admin_app/core/models/enums.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/widgets/academic_path_selector.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Cameroun -> Francophone -> Général (classe Troisième, feuille ; classe Seconde -> Série A/C)
  //          -> Anglophone -> General Education -> Form 1 (feuille)
  final serieA = AcademicNode(
    id: 'serie-a', parentId: 'seconde', nodeType: NodeType.series,
    name: 'Série A', code: 'A', countryId: 'cameroun', displayOrder: 1,
  );
  final serieC = AcademicNode(
    id: 'serie-c', parentId: 'seconde', nodeType: NodeType.series,
    name: 'Série C', code: 'C', countryId: 'cameroun', displayOrder: 2,
  );
  final seconde = AcademicNode(
    id: 'seconde', parentId: 'general', nodeType: NodeType.classType,
    name: 'Seconde', code: '2NDE', countryId: 'cameroun', displayOrder: 2,
    children: [serieA, serieC],
  );
  final troisieme = AcademicNode(
    id: 'troisieme', parentId: 'general', nodeType: NodeType.classType,
    name: 'Troisième', code: '3E', countryId: 'cameroun', displayOrder: 1,
  );
  final general = AcademicNode(
    id: 'general', parentId: 'francophone', nodeType: NodeType.educationType,
    name: 'Enseignement Général', code: 'GEN', countryId: 'cameroun',
    // Ordre volontairement inverse de l'ordre alphabétique : Seconde (2) avant Troisième (1) dans
    // le nom, mais Troisième doit s'afficher en premier car display_order=1.
    children: [troisieme, seconde],
  );
  final francophone = AcademicNode(
    id: 'francophone', parentId: 'cameroun', nodeType: NodeType.section,
    name: 'Francophone', code: 'FR', countryId: 'cameroun', displayOrder: 1,
    children: [general],
  );
  final form1 = AcademicNode(
    id: 'form1', parentId: 'general-education', nodeType: NodeType.classType,
    name: 'Form 1', code: 'F1', countryId: 'cameroun', displayOrder: 1,
  );
  final generalEducation = AcademicNode(
    id: 'general-education', parentId: 'anglophone', nodeType: NodeType.educationType,
    name: 'General Education', code: 'GE', countryId: 'cameroun', displayOrder: 1,
    children: [form1],
  );
  final anglophone = AcademicNode(
    id: 'anglophone', parentId: 'cameroun', nodeType: NodeType.section,
    name: 'Anglophone', code: 'EN', countryId: 'cameroun', displayOrder: 2,
    children: [generalEducation],
  );
  final cameroun = AcademicNode(
    id: 'cameroun', parentId: null, nodeType: NodeType.country,
    name: 'Cameroun', code: 'CMR', countryId: 'cameroun', displayOrder: 1,
    children: [francophone, anglophone],
  );

  Widget host({String? selectedId, required ValueChanged<String?> onLeafSelected}) {
    return ProviderScope(
      overrides: [
        academicTreeStreamProvider(false).overrideWith(
          (ref) => Stream.value(<AcademicNode>[cameroun]),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AcademicPathSelector(selectedNodeId: selectedId, onLeafSelected: onLeafSelected),
          ),
        ),
      ),
    );
  }

  /// Ouvre le menu déroulant au niveau `dropdownIndex` (0 = premier champ affiché) et choisit
  /// l'option `optionText` — reproduit l'interaction réelle (ouvrir puis choisir), pas un raccourci.
  Future<void> select(WidgetTester tester, int dropdownIndex, String optionText) async {
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(dropdownIndex));
    await tester.pumpAndSettle();
    await tester.tap(find.text(optionText).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Orders siblings by display_order, not alphabetically', (tester) async {
    await tester.pumpWidget(host(onLeafSelected: (_) {}));
    await tester.pumpAndSettle();

    await select(tester, 0, 'Cameroun');
    await select(tester, 1, 'Francophone');
    await select(tester, 2, 'Enseignement Général');

    // Ouvre le menu déroulant "Classe" et vérifie l'ordre des options.
    final classDropdown = find.byType(DropdownButtonFormField<String>).at(3);
    await tester.tap(classDropdown);
    await tester.pumpAndSettle();

    final troisiemeCenter = tester.getCenter(find.text('Troisième').last);
    final secondeCenter = tester.getCenter(find.text('Seconde').last);
    expect(troisiemeCenter.dy, lessThan(secondeCenter.dy));
  });

  testWidgets('Resetting a parent level clears descendant selections', (tester) async {
    String? selected;
    await tester.pumpWidget(host(onLeafSelected: (v) => selected = v));
    await tester.pumpAndSettle();

    await select(tester, 0, 'Cameroun');
    await select(tester, 1, 'Francophone');
    await select(tester, 2, 'Enseignement Général');
    await select(tester, 3, 'Seconde');
    await select(tester, 4, 'Série A');

    expect(selected, 'serie-a');
    expect(find.text('Série A'), findsWidgets);

    // Changer le sous-système doit vider Type d'Enseignement / Classe / Série immédiatement.
    await select(tester, 1, 'Anglophone');

    expect(selected, isNull);
    expect(find.text('Série A'), findsNothing);
    expect(find.text('Enseignement Général'), findsNothing);
  });

  testWidgets('Reconstructs the full path breadcrumb from an externally-selected leaf', (tester) async {
    await tester.pumpWidget(host(selectedId: 'serie-c', onLeafSelected: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Francophone'), findsWidgets);
    expect(find.text('Enseignement Général'), findsWidgets);
    expect(find.text('Seconde'), findsWidgets);
    expect(find.text('Série C'), findsWidgets);
  });

  testWidgets('Quick search resolves a class name directly to its full path', (tester) async {
    String? selected;
    await tester.pumpWidget(host(onLeafSelected: (v) => selected = v));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Form 1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Form 1').last);
    await tester.pumpAndSettle();

    expect(selected, 'form1');
    expect(find.text('Anglophone'), findsWidgets);
    expect(find.text('General Education'), findsWidgets);
  });
}
