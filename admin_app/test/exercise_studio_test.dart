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
import 'package:admin_app/features/content_management/screens/exercise_studio_screen.dart';

class MockStudioSupabaseService extends SupabaseService {
  MockStudioSupabaseService()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  Exercise? lastCreatedExercise;
  Map<String, dynamic>? lastUpdatedParams;

  Future<List<AcademicNode>> getNodesByType(String type) async {
    if (type == 'class') {
      return [
        AcademicNode(
          id: 'class-tle-c',
          nodeType: NodeType.classType,
          name: 'Terminale C',
          code: 'TC',
          countryId: 'country-cm',
          displayOrder: 1,
        ),
      ];
    }
    return [];
  }

  Future<List<Subject>> getSubjects() async {
    return [
      Subject(
        id: 'subject-maths',
        name: 'Mathématiques',
        code: 'MATH',
      ),
    ];
  }

  Future<List<Chapter>> getChapters({String? subjectId, String? classNodeId}) async {
    return [
      Chapter(
        id: 'chapter-1',
        subjectId: 'subject-maths',
        classNodeId: 'class-tle-c',
        termId: 'term-1',
        title: 'Chapitre 1 : Fonctions et Limites',
        lessons: [
          Lesson(
            id: 'lesson-1',
            chapterId: 'chapter-1',
            title: 'Limites en l\'infini',
            isPublished: true,
            isActive: true,
          ),
        ],
      ),
    ];
  }

  Future<List<Term>> getTerms({String? countryId}) async {
    return [
      Term(
        id: 'term-1',
        countryId: 'country-cm',
        name: '1er Trimestre',
        schoolYear: '2026-2027',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 12, 15),
      ),
    ];
  }

  @override
  Future<Exercise?> createExercise({
    String? lessonId,
    String? chapterId,
    String? classNodeId,
    String? termId,
    required ExerciseType type,
    required ExerciseDifficulty difficulty,
    required ExerciseFormat format,
    required String title,
    required Map<String, dynamic> instructionsJson,
    Map<String, dynamic>? solutionJson,
    String minSubscriptionTier = 'gratuit',
    List<String> skills = const [],
    List<String> prerequisites = const [],
    String provenance = 'manual',
  }) async {
    final ex = Exercise(
      id: 'created-ex-99',
      lessonId: lessonId,
      chapterId: chapterId,
      classNodeId: classNodeId,
      termId: termId,
      title: title,
      type: type,
      difficulty: difficulty,
      format: format,
      instructionsJson: instructionsJson,
      solutionJson: solutionJson ?? {},
      minSubscriptionTier: minSubscriptionTier,
      isPublished: false,
    );
    lastCreatedExercise = ex;
    return ex;
  }

  @override
  Future<void> updateExercise({
    required String id,
    String? title,
    ExerciseType? type,
    ExerciseDifficulty? difficulty,
    ExerciseFormat? format,
    Map<String, dynamic>? instructionsJson,
    Map<String, dynamic>? solutionJson,
    String? minSubscriptionTier,
    bool? isActive,
    bool updateLessonId = false,
    String? lessonId,
    bool updateChapterId = false,
    String? chapterId,
    bool updateClassNodeId = false,
    String? classNodeId,
    bool updateTermId = false,
    String? termId,
    String? editedBy,
    List<String>? skills,
    List<String>? prerequisites,
  }) async {
    lastUpdatedParams = {
      'id': id,
      'title': title,
      'type': type,
      'difficulty': difficulty,
      'format': format,
      'instructionsJson': instructionsJson,
      'solutionJson': solutionJson,
      'minSubscriptionTier': minSubscriptionTier,
      'isActive': isActive,
      'updateLessonId': updateLessonId,
      'lessonId': lessonId,
    };
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final testClass = AcademicNode(
    id: 'class-tle-c',
    nodeType: NodeType.classType,
    name: 'Terminale C',
    code: 'TC',
    countryId: 'country-cm',
    displayOrder: 1,
  );

  final testTerm1 = Term(
    id: 'term-1',
    countryId: 'country-cm',
    name: '1er Trimestre',
    schoolYear: '2026-2027',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 12, 15),
  );

  final mockService = MockStudioSupabaseService();

  Widget createSubjectUnderTest({Exercise? existingExercise}) {
    return ProviderScope(
      overrides: [
        supabaseServiceProvider.overrideWithValue(mockService),
        nodesByTypeProvider('class').overrideWith((ref) async => [testClass]),
        nodesByTypeProvider('series').overrideWith((ref) async => []),
        termsProvider(null).overrideWith((ref) async => [testTerm1]),
      ],
      child: MaterialApp(
        home: ExerciseStudioScreen(existingExercise: existingExercise),
      ),
    );
  }

  testWidgets('ExerciseStudioScreen renders all 3 tabs and top bar in creation mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // Vérifier l'en-tête du Studio
    expect(find.text("Studio d'Exercice"), findsOneWidget);
    expect(find.text('Nouvel exercice'), findsWidgets);
    expect(find.text('Enregistrer'), findsOneWidget);

    // Vérifier les 3 onglets principaux
    expect(find.text('1. Énoncé & Médias'), findsOneWidget);
    expect(find.text('2. Choix & Corrigé'), findsOneWidget);
    expect(find.text('3. Rattachement & Métadonnées'), findsOneWidget);

    // Par défaut on est sur l'onglet 1 (Énoncé & Médias)
    expect(find.text("Titre de l'exercice *"), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('ExerciseStudioScreen tab switching works smoothly without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // Basculer vers l'onglet 2 : Choix & Corrigé
    await tester.tap(find.text('2. Choix & Corrigé'));
    await tester.pumpAndSettle();

    // On doit voir les sections d'options QCM et de corrigé
    expect(find.text('Corrigé détaillé / Démonstration pas à pas'), findsOneWidget);
    expect(find.text('Indices progressifs (un par ligne)'), findsOneWidget);

    // Basculer vers l'onglet 3 : Rattachement & Métadonnées
    await tester.tap(find.text('3. Rattachement & Métadonnées'));
    await tester.pumpAndSettle();

    // On doit voir les 3 niveaux académiques (Leçon, Chapitre, Examen)
    expect(find.text('Niveau 1 : Leçon précise'), findsOneWidget);
    expect(find.text('Niveau 2 : Chapitre général'), findsOneWidget);
    expect(find.text('Niveau 3 : Type Examen'), findsOneWidget);
  });

  testWidgets('ExerciseStudioScreen populates existing exercise data in edit mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final existing = Exercise(
      id: 'ex-existing-1',
      lessonId: 'lesson-1',
      chapterId: 'chapter-1',
      classNodeId: 'class-tle-c',
      termId: 'term-1',
      title: 'Exercice de Limites Remarquables',
      type: ExerciseType.training,
      difficulty: ExerciseDifficulty.approfondissement,
      format: ExerciseFormat.qcm,
      isPublished: true,
      isActive: true,
      instructionsJson: {
        'statement': 'Calculer la limite quand x tend vers 0 de sin(x)/x.',
        'options': ['Option A', 'Option B', '+infini', 'Inexistante'],
      },
      solutionJson: {
        'correct_index': 1,
        'correction': 'Par le theoreme des taux d\'accroissement, lim = 1.',
      },
    );

    await tester.pumpWidget(createSubjectUnderTest(existingExercise: existing));
    await tester.pumpAndSettle();

    // Vérifier que le titre de l'exercice existant est chargé
    expect(find.text("Studio d'Exercice"), findsOneWidget);
    expect(find.text('Exercice de Limites Remarquables'), findsWidgets);
    expect(find.text('PUBLIÉ'), findsOneWidget);

    // Aller sur l'onglet Choix & Corrigé
    await tester.tap(find.text('2. Choix & Corrigé'));
    await tester.pumpAndSettle();

    // Vérifier que les options sont chargées
    expect(find.text('Option A'), findsWidgets);
    expect(find.text('Option B'), findsWidgets);
    expect(find.text('Inexistante'), findsWidgets);
  });
}
