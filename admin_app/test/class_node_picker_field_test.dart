import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_app/core/models/academic_node.dart';
import 'package:admin_app/core/models/enums.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/widgets/class_node_picker_field.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Cameroun (1 enfant, non terminal) -> Francophone (1 enfant, non terminal) -> Général
  // (2 enfants : Sixième [feuille] et Seconde [a des séries]) -> sous Seconde : Série A, Série C.
  final serieA = AcademicNode(
    id: 'serie-a',
    parentId: 'seconde',
    nodeType: NodeType.series,
    name: 'Série A',
    code: 'A',
    countryId: 'cameroun',
  );
  final serieC = AcademicNode(
    id: 'serie-c',
    parentId: 'seconde',
    nodeType: NodeType.series,
    name: 'Série C',
    code: 'C',
    countryId: 'cameroun',
  );
  final seconde = AcademicNode(
    id: 'seconde',
    parentId: 'general',
    nodeType: NodeType.classType,
    name: 'Seconde',
    code: '2NDE',
    countryId: 'cameroun',
    children: [serieA, serieC],
  );
  final sixieme = AcademicNode(
    id: 'sixieme',
    parentId: 'general',
    nodeType: NodeType.classType,
    name: 'Sixième',
    code: '6E',
    countryId: 'cameroun',
  );
  final general = AcademicNode(
    id: 'general',
    parentId: 'francophone',
    nodeType: NodeType.educationType,
    name: 'Général',
    code: 'GEN',
    countryId: 'cameroun',
    children: [sixieme, seconde],
  );
  final francophone = AcademicNode(
    id: 'francophone',
    parentId: 'cameroun',
    nodeType: NodeType.section,
    name: 'Francophone',
    code: 'FR',
    countryId: 'cameroun',
    children: [general],
  );
  final cameroun = AcademicNode(
    id: 'cameroun',
    parentId: null,
    nodeType: NodeType.country,
    name: 'Cameroun',
    code: 'CMR',
    countryId: 'cameroun',
    children: [francophone],
  );

  Widget host({String? selectedId}) {
    var current = selectedId;
    return ProviderScope(
      overrides: [
        academicTreeStreamProvider(false).overrideWith(
          (ref) => Stream.value(<AcademicNode>[cameroun]),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ClassNodePickerField(
              selectedId: current,
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Auto-skips single-child levels straight to the branching level', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Cameroun -> Francophone -> Général sautés automatiquement (1 seul enfant à chaque niveau) :
    // la boîte de dialogue doit directement proposer Sixième et Seconde.
    expect(find.text('Sixième'), findsOneWidget);
    expect(find.text('Seconde'), findsOneWidget);
  });

  testWidgets('Combines class name with série when navigating into it', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seconde'));
    await tester.pumpAndSettle();

    expect(find.text('Seconde A'), findsOneWidget);
    expect(find.text('Seconde C'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('Selecting a leaf closes the dialog and reports the combined label', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seconde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seconde A'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Seconde A'), findsOneWidget);
  });
}
