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
import 'package:admin_app/features/content_management/screens/lessons_manager_screen.dart';

class MockLessonSupabaseService extends SupabaseService {
  MockLessonSupabaseService()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<Map<String, String>> fetchValidationStatusForContentIds(
    List<String> contentIds,
  ) async {
    return {
      'lesson-1': 'publie',
      'lesson-2': 'en_attente',
      'lesson-3': 'brouillon',
    };
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // La classe doit être une feuille rattachée au pays pour que l'AcademicPathSelector (qui lit
  // academicTreeStreamProvider, pas nodesByTypeProvider('class')) puisse la retrouver et la
  // proposer via sa recherche rapide.
  final testClass = AcademicNode(
    id: 'class-tle-c',
    parentId: 'country-cm',
    nodeType: NodeType.classType,
    name: 'Terminale C',
    code: 'TC',
    countryId: 'country-cm',
    displayOrder: 1,
  );

  final testCountry = AcademicNode(
    id: 'country-cm',
    nodeType: NodeType.country,
    name: 'Cameroun',
    code: 'CM',
    displayOrder: 1,
    children: [testClass],
  );

  final testSubject = Subject(
    id: 'subject-maths',
    name: 'Mathématiques',
    code: 'MATH',
    countryId: 'country-cm',
  );

  final testTerm1 = Term(
    id: 'term-1',
    countryId: 'country-cm',
    name: '1er Trimestre',
    schoolYear: '2026-2027',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 12, 15),
  );

  final lesson1 = Lesson(
    id: 'lesson-1',
    chapterId: 'chapter-1',
    title: 'Limites et Continuité',
    isPublished: true,
    isActive: true,
    minSubscriptionTier: 'free',
    contentJson: {'body': 'Cours sur les limites'},
  );

  final lesson2 = Lesson(
    id: 'lesson-2',
    chapterId: 'chapter-1',
    title: 'Dérivées et Primitives',
    isPublished: false,
    isActive: true,
    minSubscriptionTier: 'premium',
    contentJson: {'body': 'Cours sur les dérivées'},
  );

  final lesson3Archived = Lesson(
    id: 'lesson-3',
    chapterId: 'chapter-2',
    title: 'Ancienne Leçon Archivée',
    isPublished: false,
    isActive: false,
    minSubscriptionTier: 'free',
    contentJson: {'body': 'Ancien cours'},
  );

  final chapter1 = Chapter(
    id: 'chapter-1',
    subjectId: 'subject-maths',
    classNodeId: 'class-tle-c',
    termId: 'term-1',
    title: 'Chapitre 1 : Analyse Fonctionnelle',
    introduction: 'Étude complète des fonctions réelles',
    isActive: true,
    lessons: [lesson1, lesson2],
  );

  final chapter2 = Chapter(
    id: 'chapter-2',
    subjectId: 'subject-maths',
    classNodeId: 'class-tle-c',
    termId: 'term-1',
    title: 'Chapitre 2 : Suites Numériques',
    introduction: 'Suites arithmétiques et géométriques',
    isActive: true,
    lessons: [lesson3Archived],
  );

  Widget createSubjectUnderTest({
    List<AcademicNode>? classes,
    List<Subject>? subjects,
    List<Chapter>? chapters,
  }) {
    return ProviderScope(
      overrides: [
        supabaseServiceProvider.overrideWithValue(MockLessonSupabaseService()),
        nodesByTypeProvider('country').overrideWith((ref) async => [testCountry]),
        nodesByTypeProvider('class').overrideWith(
          (ref) async => classes ?? [testClass],
        ),
        nodesByTypeProvider('series').overrideWith((ref) async => []),
        academicTreeStreamProvider(false).overrideWith(
          (ref) => Stream.value(classes ?? [testCountry]),
        ),
        subjectsForClassProvider(testClass.id).overrideWith(
          (ref) async => subjects ?? [testSubject],
        ),
        termsProvider('country-cm').overrideWith((ref) async => [testTerm1]),
        chaptersWithLessonsProvider((
          subjectId: 'subject-maths',
          classNodeId: 'class-tle-c',
          includeInactive: false,
        )).overrideWith((ref) async => chapters ?? [chapter1, chapter2]),
        chaptersWithLessonsProvider((
          subjectId: 'subject-maths',
          classNodeId: 'class-tle-c',
          includeInactive: true,
        )).overrideWith((ref) async => chapters ?? [chapter1, chapter2]),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: LessonsManagerScreen(),
        ),
      ),
    );
  }

  /// Sélectionne une classe via le raccourci de recherche de l'AcademicPathSelector (premier
  /// TextField de l'écran, avant celui de recherche de chapitres/leçons) — reproduit le nouveau
  /// parcours de navigation explicite qui remplace l'ancienne auto-sélection de "la première
  /// classe" (voir lessons_manager_screen.dart, `_buildClassPathSelector`).
  Future<void> selectClass(WidgetTester tester, String className) async {
    await tester.enterText(find.byType(TextField).first, className);
    await tester.pumpAndSettle();
    await tester.tap(find.text(className).last);
    await tester.pumpAndSettle();
  }

  testWidgets('LessonsManagerScreen renders modern header and filter controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Gestion des Leçons & Cours'), findsOneWidget);
    expect(find.text('Créer un Chapitre'), findsOneWidget);
    // Remplacé par l'AcademicPathSelector : plus de libellé "Classe :" fixe, mais son raccourci de
    // recherche rapide est bien affiché.
    expect(find.textContaining('Rechercher une classe'), findsOneWidget);
    expect(find.text('Matière :'), findsOneWidget);
    // Un TextField pour la recherche de classe (AcademicPathSelector), un pour la recherche de
    // chapitres/leçons (barre de filtres).
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Afficher les archives'), findsOneWidget);
  });

  testWidgets('KPI Metrics Row calculates and displays counts accurately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();
    await selectClass(tester, 'Terminale C');

    // KPI Cards: Total Chapitres (2), Total Leçons (3), Leçons Publiées (1), En Validation (1), Archivés (1)
    expect(find.text('Total Chapitres'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    expect(find.text('Total Leçons'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    expect(find.text('Leçons Publiées'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    expect(find.text('En Validation'), findsOneWidget);
    expect(find.text('Éléments Archivés'), findsOneWidget);
  });

  testWidgets('Chapter Card displays modern badges and action toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();
    await selectClass(tester, 'Terminale C');

    expect(find.text('Chapitre 1 : Analyse Fonctionnelle'), findsOneWidget);
    expect(find.text('Étude complète des fonctions réelles'), findsOneWidget);
    expect(find.text('Terminale C'), findsWidgets);
    expect(find.text('1er Trimestre'), findsWidgets);

    // Action toolbar buttons
    expect(find.text('Ajouter une leçon ici'), findsWidgets);
    expect(find.text('Modifier'), findsWidgets);
    expect(find.byTooltip('Options du chapitre'), findsWidgets);
  });

  testWidgets('Lesson Row renders title, status badges, and quick actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();
    await selectClass(tester, 'Terminale C');

    expect(find.text('Limites et Continuité'), findsOneWidget);
    expect(find.text('Publiée'), findsOneWidget);
    expect(find.text('free'), findsWidgets);

    expect(find.text('Dérivées et Primitives'), findsOneWidget);
    expect(find.text('En attente de validation'), findsOneWidget);
    expect(find.text('premium'), findsOneWidget);

    expect(find.byTooltip('Aperçu'), findsWidgets);
    expect(find.byTooltip('Autres actions'), findsWidgets);
  });

  testWidgets('Search input filters chapters and lessons in real-time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();
    await selectClass(tester, 'Terminale C');

    expect(find.text('Chapitre 1 : Analyse Fonctionnelle'), findsOneWidget);
    expect(find.text('Chapitre 2 : Suites Numériques'), findsOneWidget);

    // Le premier TextField est le raccourci de recherche de classe (AcademicPathSelector) ; celui
    // de recherche de chapitres/leçons est le second.
    final chapterSearchField = find.byType(TextField).last;

    // Filter by "Suites"
    await tester.enterText(chapterSearchField, 'Suites');
    await tester.pumpAndSettle();

    expect(find.text('Chapitre 2 : Suites Numériques'), findsOneWidget);
    expect(find.text('Chapitre 1 : Analyse Fonctionnelle'), findsNothing);

    // Filter non-existent
    await tester.enterText(chapterSearchField, 'InexistantXYZ');
    await tester.pumpAndSettle();

    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('Effacer la recherche'), findsOneWidget);

    // Tap clear button
    await tester.tap(find.text('Effacer la recherche'));
    await tester.pumpAndSettle();

    expect(find.text('Chapitre 1 : Analyse Fonctionnelle'), findsOneWidget);
    expect(find.text('Chapitre 2 : Suites Numériques'), findsOneWidget);
  });
}
