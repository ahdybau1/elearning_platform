import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/models/academic_node.dart';
import 'package:admin_app/core/models/enums.dart';
import 'package:admin_app/core/models/content_models.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/academic_tree/screens/academic_tree_screen.dart';

class MockTreeService extends SupabaseService {
  MockTreeService()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<int> countProfilesForNode(String nodeId) async => 0;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Arbre de test hiérarchique : Cameroun -> Enseignement Secondaire -> Terminale -> Série C
  final serieC = AcademicNode(
    id: 'node-serie-c',
    parentId: 'node-terminale',
    nodeType: NodeType.series,
    name: 'Série C',
    code: 'SERIE-C',
    countryId: 'node-cameroon',
    displayOrder: 1,
    isActive: true,
  );

  final terminale = AcademicNode(
    id: 'node-terminale',
    parentId: 'node-sec',
    nodeType: NodeType.classType,
    name: 'Terminale',
    code: 'TLE',
    countryId: 'node-cameroon',
    displayOrder: 1,
    isActive: true,
    children: [serieC],
  );

  final enseignementSecondaire = AcademicNode(
    id: 'node-sec',
    parentId: 'node-cameroon',
    nodeType: NodeType.educationType,
    name: 'Enseignement Secondaire',
    code: 'SEC',
    countryId: 'node-cameroon',
    displayOrder: 1,
    isActive: true,
    children: [terminale],
  );

  final cameroon = AcademicNode(
    id: 'node-cameroon',
    parentId: null,
    nodeType: NodeType.country,
    name: 'Cameroun',
    code: 'CMR',
    countryId: 'node-cameroon',
    displayOrder: 1,
    isActive: true,
    children: [enseignementSecondaire],
  );

  final sampleTree = <AcademicNode>[cameroon];

  Widget host(Widget child, {List<AcademicNode>? treeData}) {
    final activeTree = treeData ?? sampleTree;
    return ProviderScope(
      overrides: [
        supabaseServiceProvider.overrideWithValue(MockTreeService()),
        academicTreeStreamProvider(false).overrideWith(
          (ref) => Stream.value(activeTree),
        ),
        academicTreeStreamProvider(true).overrideWith(
          (ref) => Stream.value(activeTree),
        ),
        twinGroupsProvider.overrideWith(
          (ref) => Future.value(<TwinGroup>[]),
        ),
        subjectsForClassProvider.overrideWith(
          (ref, _) => Future.value(<Subject>[]),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Renders root level countries and global actions', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const AcademicTreeScreen()));
    await tester.pumpAndSettle();

    // Vérifie le titre principal
    expect(find.text('Arbre Académique & Systèmes Éducatifs'), findsOneWidget);
    // Vérifie les actions globales
    expect(find.text('Ajouter un Pays'), findsOneWidget);
    expect(find.text('Fusionner des Classes'), findsOneWidget);
    expect(find.text('Jumeler des Classes'), findsOneWidget);
    // Vérifie la présence de la carte Cameroun
    expect(find.text('Cameroun'), findsOneWidget);
    expect(find.text('Explorer le système'), findsOneWidget);
  });

  testWidgets('Explores down level-by-level: Country -> Education -> Class -> Series', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const AcademicTreeScreen()));
    await tester.pumpAndSettle();

    // 1. Clic sur "Explorer le système" pour entrer dans Cameroun
    await tester.ensureVisible(find.text('Explorer le système'));
    await tester.tap(find.text('Explorer le système'));
    await tester.pumpAndSettle();

    // Doit afficher la vue pleine page du pays avec fil d'Ariane
    expect(find.text('Arbre académique'), findsOneWidget);
    expect(find.text('Retour à l\'accueil (Pays)'), findsOneWidget);
    expect(find.text('Enseignement Secondaire'), findsOneWidget);

    // 2. Clic sur "Explorer" pour entrer dans Enseignement Secondaire
    await tester.ensureVisible(find.text('Explorer').first);
    await tester.tap(find.text('Explorer').first);
    await tester.pumpAndSettle();

    // Doit afficher la vue pleine page de Enseignement Secondaire
    expect(find.text('Retour à Cameroun'), findsOneWidget);
    expect(find.text('Terminale'), findsOneWidget);

    // 3. Clic sur "Explorer" pour entrer dans Terminale
    await tester.ensureVisible(find.text('Explorer').first);
    await tester.tap(find.text('Explorer').first);
    await tester.pumpAndSettle();

    // Doit afficher la vue pleine page de Terminale
    expect(find.text('Retour à Enseignement Secondaire'), findsOneWidget);
    expect(find.text('Série C'), findsOneWidget);

    // 4. Clic sur "Explorer" pour entrer dans Série C (niveau terminal)
    await tester.ensureVisible(find.text('Explorer').first);
    await tester.tap(find.text('Explorer').first);
    await tester.pumpAndSettle();

    // Doit afficher la vue pleine page de Série C avec le bandeau terminal
    expect(find.text('Retour à Terminale'), findsOneWidget);
    expect(find.text('Niveau Terminal de l\'Arbre Académique'), findsOneWidget);
  });

  testWidgets('Navigates back using back button and breadcrumb', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const AcademicTreeScreen()));
    await tester.pumpAndSettle();

    // Entrer dans Cameroun
    await tester.ensureVisible(find.text('Explorer le système'));
    await tester.tap(find.text('Explorer le système'));
    await tester.pumpAndSettle();
    expect(find.text('Retour à l\'accueil (Pays)'), findsOneWidget);

    // Retour via le bouton Retour
    await tester.ensureVisible(find.text('Retour à l\'accueil (Pays)'));
    await tester.tap(find.text('Retour à l\'accueil (Pays)'));
    await tester.pumpAndSettle();

    // Doit être revenu à l'accueil
    expect(find.text('Arbre Académique & Systèmes Éducatifs'), findsOneWidget);
    expect(find.text('Explorer le système'), findsOneWidget);

    // Ré-entrer dans Cameroun puis dans Enseignement Secondaire
    await tester.ensureVisible(find.text('Explorer le système'));
    await tester.tap(find.text('Explorer le système'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explorer').first);
    await tester.tap(find.text('Explorer').first);
    await tester.pumpAndSettle();
    expect(find.text('Retour à Cameroun'), findsOneWidget);

    // Clic sur "Arbre académique" dans le fil d'Ariane pour revenir directement à la racine
    await tester.ensureVisible(find.text('Arbre académique'));
    await tester.tap(find.text('Arbre académique'));
    await tester.pumpAndSettle();

    expect(find.text('Arbre Académique & Systèmes Éducatifs'), findsOneWidget);
  });

  testWidgets('Global search finds deep nodes and jumps directly to dedicated view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const AcademicTreeScreen()));
    await tester.pumpAndSettle();

    // Saisie de recherche "Série C"
    await tester.enterText(find.byType(TextField).first, 'Série C');
    await tester.pumpAndSettle();

    // Vérifie le résultat de recherche
    expect(find.text('Résultats de la recherche'), findsOneWidget);
    expect(find.text('Cameroun › Enseignement Secondaire › Terminale › Série C'), findsOneWidget);

    // Clic sur "Ouvrir" du résultat
    await tester.ensureVisible(find.text('Ouvrir'));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Doit avoir sauté directement à la vue de Série C avec son fil d'Ariane
    expect(find.text('Niveau Terminal de l\'Arbre Académique'), findsOneWidget);
    expect(find.text('Retour à Terminale'), findsOneWidget);
  });

  testWidgets('Navigation toolbar supports dual-direction history: Précédent & Suivant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const AcademicTreeScreen()));
    await tester.pumpAndSettle();

    // 1. Initialement à la racine: Précédent et Suivant sont présents
    expect(find.text('Précédent'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Racine'), findsOneWidget);

    // 2. Entrer dans Cameroun
    await tester.ensureVisible(find.text('Explorer le système'));
    await tester.tap(find.text('Explorer le système'));
    await tester.pumpAndSettle();

    expect(find.text('Enseignement Secondaire'), findsOneWidget);

    // 3. Cliquer sur "Précédent" dans la barre de navigation
    await tester.tap(find.text('Précédent'));
    await tester.pumpAndSettle();

    // Doit être revenu à l'accueil
    expect(find.text('Arbre Académique & Systèmes Éducatifs'), findsOneWidget);

    // 4. Cliquer sur "Suivant" dans la barre de navigation
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    // Doit être retourné en avant dans Cameroun !
    expect(find.text('Enseignement Secondaire'), findsOneWidget);

    // 5. Entrer dans Enseignement Secondaire puis dans Terminale
    await tester.ensureVisible(find.text('Explorer').first);
    await tester.tap(find.text('Explorer').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Explorer').first);
    await tester.tap(find.text('Explorer').first);
    await tester.pumpAndSettle();

    expect(find.text('Série C'), findsOneWidget);

    // 6. Cliquer sur "Précédent" -> revient à Enseignement Secondaire
    await tester.tap(find.text('Précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Retour à Cameroun'), findsOneWidget);

    // 7. Cliquer sur "Suivant" -> revient à Terminale
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Retour à Enseignement Secondaire'), findsOneWidget);

    // 8. Cliquer sur le bouton "Racine" -> retour direct à l'accueil
    await tester.tap(find.text('Racine'));
    await tester.pumpAndSettle();
    expect(find.text('Arbre Académique & Systèmes Éducatifs'), findsOneWidget);

    // 9. Cliquer sur "Précédent" depuis la racine après avoir sauté -> revient à Terminale
    await tester.tap(find.text('Précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Retour à Enseignement Secondaire'), findsOneWidget);
  });

  for (final width in [345.0, 390.0, 800.0, 1400.0]) {
    testWidgets('Academic tree fits viewport width $width without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host(const AcademicTreeScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cameroun'), findsOneWidget);
    });
  }
}
