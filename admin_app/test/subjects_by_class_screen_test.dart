import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/models/academic_node.dart';
import 'package:admin_app/core/models/content_models.dart';
import 'package:admin_app/core/models/enums.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/academic_tree/screens/subjects_by_class_screen.dart';

class _FakeService extends SupabaseService {
  _FakeService()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<List<Subject>> fetchSubjects({
    Set<String>? countryIds,
    bool includeInactive = false,
  }) async => <Subject>[];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final node = AcademicNode(
    id: 'node-premiere-ti',
    parentId: 'node-premiere',
    nodeType: NodeType.series,
    name: 'Série TI',
    code: 'TI',
    countryId: 'node-cameroon',
    isActive: true,
  );

  final links = <SubjectClassLink>[
    SubjectClassLink(
      id: 'link-1',
      subjectId: 'sub-algo',
      subjectName: 'Algorithmique et Programmation',
      classNodeId: node.id,
      isMandatory: true,
      isOptional: false,
      verificationStatus: 'SECONDARY_SOURCE_CONFIRMED',
      curriculumName: 'Algorithmique et Programmation — Première TI',
    ),
    SubjectClassLink(
      id: 'link-2',
      subjectId: 'sub-allemand',
      subjectName: 'Allemand',
      classNodeId: node.id,
      isMandatory: false,
      isOptional: true,
      choiceGroup: 'LANGUE_VIVANTE_II',
      verificationStatus: 'SECONDARY_SOURCE_CONFIRMED',
    ),
  ];

  Widget host(Widget child, {List<SubjectClassLink>? assignments}) {
    return ProviderScope(
      overrides: [
        supabaseServiceProvider.overrideWithValue(_FakeService()),
        subjectAssignmentsProvider(node.id).overrideWith(
          (ref) => Future.value(assignments ?? links),
        ),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: child),
    );
  }

  testWidgets('Distinguishes mandatory subjects from optional choice groups', (tester) async {
    await tester.pumpWidget(
      host(SubjectsByClassScreen(node: node, displayLabel: 'Première TI')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Matières — Première TI'), findsOneWidget);
    expect(find.textContaining('Matières obligatoires'), findsOneWidget);
    expect(find.textContaining('Au choix — LANGUE_VIVANTE_II'), findsOneWidget);
    expect(find.text('Algorithmique et Programmation'), findsOneWidget);
    expect(find.text('Allemand'), findsOneWidget);
  });

  testWidgets('Shows an honest empty state instead of a blank page', (tester) async {
    await tester.pumpWidget(
      host(SubjectsByClassScreen(node: node, displayLabel: 'Terminale F3'), assignments: []),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune matière rattachée'), findsOneWidget);
  });

  testWidgets('Add-subject button opens the assignment modal', (tester) async {
    await tester.pumpWidget(
      host(SubjectsByClassScreen(node: node, displayLabel: 'Première TI'), assignments: []),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter une matière'));
    await tester.pumpAndSettle();

    expect(find.text('Nom de la matière'), findsOneWidget);
    expect(find.text('Obligatoire'), findsOneWidget);
  });
}
