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
import 'package:admin_app/features/content_management/screens/exercises_manager_screen.dart';
import 'package:admin_app/features/content_management/screens/exercise_detail_screen.dart';
import 'package:admin_app/features/content_management/screens/exercise_student_preview_screen.dart';
import 'package:admin_app/features/content_management/screens/exercise_ai_generation_screen.dart';

class MockExerciseSupabaseService extends SupabaseService {
  MockExerciseSupabaseService()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<Lesson?> getLesson(String id) async {
    return Lesson(
      id: id,
      chapterId: 'chapter-1',
      title: 'Limites et Continuité',
      isPublished: true,
      isActive: true,
    );
  }

  @override
  Future<Chapter?> getChapter(String id) async {
    return Chapter(
      id: id,
      subjectId: 'subject-maths',
      classNodeId: 'class-tle-c',
      termId: 'term-1',
      title: 'Chapitre 1 : Analyse',
      lessons: [],
    );
  }

  @override
  Future<Exercise?> duplicateExercise(String exerciseId, String adminId) async => null;

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
  }) async {}

  @override
  Future<void> permanentlyDeleteExercise(String id, String adminId) async {}

  @override
  Future<List<Map<String, dynamic>>> generateAiExercises({
    String? subjectId,
    String? chapterId,
    required ExerciseType type,
    required ExerciseDifficulty difficulty,
    required ExerciseFormat format,
    required int count,
    String? rawNotes,
    String? promptDirectives,
    List<Map<String, dynamic>>? existingExercises,
  }) async {
    return [
      {
        'title': 'Exercice Simulé IA',
        'statement': 'Résoudre dans R : 2x + 4 = 0',
        'options': ['-2', '2', '0', '4'],
        'hints': ['Isoler le terme en x'],
        'correction': '2x = -4 donc x = -2',
        'explanation': 'Équation linéaire du premier degré.',
        'correct_index': 0,
        'skills': ['Algèbre de base'],
        'prerequisites': ['Arithmétique élémentaire'],
      }
    ];
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

  final ex1 = Exercise(
    id: 'ex-1',
    lessonId: 'lesson-1',
    chapterId: 'chapter-1',
    classNodeId: 'class-tle-c',
    termId: 'term-1',
    title: 'Calcul de dérivée polynomiale',
    type: ExerciseType.training,
    difficulty: ExerciseDifficulty.facile,
    format: ExerciseFormat.qcm,
    isPublished: true,
    isActive: true,
    instructionsJson: {
      'statement': 'Quelle est la dérivée de x^2 ?',
      'options': ['2x', 'x', 'x^2', '0'],
      'hints': ['Appliquer la règle de dérivation x^n -> n*x^(n-1)'],
    },
    solutionJson: {
      'correct_index': 0,
      'explanation': 'd/dx(x^2) = 2x',
      'correction': 'En utilisant la formule fondamentale pour n=2, la dérivée donne immédiatement 2x.',
    },
  );

  final ex2 = Exercise(
    id: 'ex-2',
    lessonId: 'lesson-1',
    chapterId: 'chapter-1',
    classNodeId: 'class-tle-c',
    termId: 'term-1',
    title: 'Théorème des valeurs intermédiaires',
    type: ExerciseType.evaluation,
    difficulty: ExerciseDifficulty.intermediaire,
    format: ExerciseFormat.reponseCourte,
    isPublished: false,
    isActive: true,
    instructionsJson: {
      'statement': 'Démontrer que f(x) = 0 admet au moins une solution.',
    },
  );

  // Examen Niveau 3 (sans chapterId ni lessonId)
  final ex3Exam = Exercise(
    id: 'ex-3',
    lessonId: null,
    chapterId: null,
    classNodeId: 'class-tle-c',
    termId: null,
    title: 'Épreuve Blanche Baccalauréat 2026',
    type: ExerciseType.evaluation,
    difficulty: ExerciseDifficulty.approfondissement,
    format: ExerciseFormat.qcm,
    isPublished: true,
    isActive: true,
    instructionsJson: {
      'statement': 'Sujet complet du baccalauréat blanc...',
    },
  );

  final ex4Archived = Exercise(
    id: 'ex-4',
    lessonId: 'lesson-1',
    chapterId: 'chapter-1',
    classNodeId: 'class-tle-c',
    termId: 'term-1',
    title: 'Ancien exercice archivé',
    type: ExerciseType.training,
    difficulty: ExerciseDifficulty.facile,
    format: ExerciseFormat.qcm,
    isPublished: false,
    isActive: false,
    instructionsJson: {
      'statement': 'Exercice hors programme obsolète',
    },
  );

  final defaultExercises = [ex1, ex2, ex3Exam, ex4Archived];

  Widget createSubjectUnderTest({
    List<Exercise>? exercises,
  }) {
    final listToUse = exercises ?? defaultExercises;
    return ProviderScope(
      overrides: [
        supabaseServiceProvider.overrideWithValue(MockExerciseSupabaseService()),
        nodesByTypeProvider('class').overrideWith((ref) async => [testClass]),
        nodesByTypeProvider('series').overrideWith((ref) async => []),
        termsProvider(null).overrideWith((ref) async => [testTerm1]),
        exercisesProvider(false).overrideWith(
          (ref) async => listToUse.where((e) => e.isActive).toList(),
        ),
        exercisesProvider(true).overrideWith(
          (ref) async => listToUse,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ExercisesManagerScreen(),
        ),
      ),
    );
  }

  testWidgets('ExercisesManagerScreen renders header, top-level tabs and action buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // En-tête de la page principale
    expect(find.text("Banque d'Exercices"), findsOneWidget);
    expect(find.text('+ Nouvel Exercice (Studio)'), findsOneWidget);
    expect(find.text('Générateur IA'), findsOneWidget);

    // Onglets thématiques du Hub
    expect(find.text('Exercices du Programme (Niveaux 1 & 2)'), findsOneWidget);
    expect(find.text('Examens & Concours (Niveau 3)'), findsOneWidget);

    // Dans l'onglet Programme : ex1 et ex2 sont visibles
    expect(find.text('Calcul de dérivée polynomiale'), findsOneWidget);
    expect(find.text('Théorème des valeurs intermédiaires'), findsOneWidget);
    // ex3Exam (niveau 3) ne doit pas être affiché dans l'onglet Programme
    expect(find.text('Épreuve Blanche Baccalauréat 2026'), findsNothing);
  });

  testWidgets('Switching to Examens & Concours tab displays Level 3 standalone exercises', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // Cliquer sur l'onglet "Examens & Concours (Niveau 3)"
    await tester.tap(find.text('Examens & Concours (Niveau 3)'));
    await tester.pumpAndSettle();

    // ex3Exam est désormais visible
    expect(find.text('Épreuve Blanche Baccalauréat 2026'), findsOneWidget);
    // ex1 et ex2 ne doivent plus être visibles ici
    expect(find.text('Calcul de dérivée polynomiale'), findsNothing);
    expect(find.text('Théorème des valeurs intermédiaires'), findsNothing);
  });

  testWidgets('Search query filters curriculum exercises and clear icon resets search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    // Taper une recherche
    await tester.enterText(searchField, 'dérivée');
    await tester.pumpAndSettle();

    expect(find.text('Calcul de dérivée polynomiale'), findsOneWidget);
    expect(find.text('Théorème des valeurs intermédiaires'), findsNothing);

    // Bouton effacer la recherche
    final clearBtn = find.byTooltip('Effacer la recherche');
    expect(clearBtn, findsOneWidget);

    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    expect(find.text('Calcul de dérivée polynomiale'), findsOneWidget);
    expect(find.text('Théorème des valeurs intermédiaires'), findsOneWidget);
  });

  testWidgets('Tapping Consulter navigates to dedicated ExerciseDetailScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // Cliquer sur le bouton Consulter du premier exercice
    final consultBtn = find.text('Consulter').first;
    expect(consultBtn, findsOneWidget);

    await tester.tap(consultBtn);
    await tester.pumpAndSettle();

    // On se trouve maintenant sur l'interface dédiée ExerciseDetailScreen
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    expect(find.text('ÉNONCÉ DE L\'EXERCICE'), findsOneWidget);
    expect(find.text('Modifier dans le Studio'), findsOneWidget);
    expect(find.text('Aperçu Élève'), findsOneWidget);

    // Vérifier l'interactivité de la simulation de choix étudiant
    expect(find.text('2x'), findsOneWidget);
    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();

    // La réponse correcte est cochée en vert avec icône check
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    expect(find.text('Réinitialiser'), findsOneWidget);

    // Réinitialiser la simulation
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('Réinitialiser'), findsNothing);

    // Revenir en arrière vers le Hub
    await tester.tap(find.byTooltip('Retour à la Banque d\'Exercices'));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseDetailScreen), findsNothing);
    expect(find.byType(ExercisesManagerScreen), findsOneWidget);
  });

  testWidgets('Tapping Aperçu navigates to full-screen ExerciseStudentPreviewScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // Cliquer sur le bouton Aperçu du premier exercice
    final previewBtn = find.text('Aperçu').first;
    expect(previewBtn, findsOneWidget);

    await tester.tap(previewBtn);
    await tester.pumpAndSettle();

    // On se trouve sur la page dédiée d'immersion élève
    expect(find.byType(ExerciseStudentPreviewScreen), findsOneWidget);
    expect(find.text('Aperçu Élève (Immersion Réelle)'), findsOneWidget);
    expect(find.text('Mobile (390px)'), findsOneWidget);
    expect(find.text('Plein Écran'), findsOneWidget);

    // Fermer l'aperçu et revenir
    await tester.tap(find.byTooltip('Fermer l\'aperçu'));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseStudentPreviewScreen), findsNothing);
    expect(find.byType(ExercisesManagerScreen), findsOneWidget);
  });

  testWidgets('Tapping Générateur IA navigates to dedicated ExerciseAiGenerationScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    // Cliquer sur le bouton "Générateur IA" dans le header
    final aiBtn = find.text('Générateur IA');
    expect(aiBtn, findsOneWidget);

    await tester.tap(aiBtn);
    await tester.pumpAndSettle();

    // On se trouve sur la page de génération IA complète
    expect(find.byType(ExerciseAiGenerationScreen), findsOneWidget);
    expect(find.text('Générateur d\'Exercices Assisté par IA'), findsOneWidget);
    expect(find.text('Générer avec l\'IA'), findsOneWidget);
    expect(find.text('Paramètres de Génération'), findsOneWidget);

    // Revenir en arrière
    await tester.tap(find.byTooltip('Retour').first);
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseAiGenerationScreen), findsNothing);
    expect(find.byType(ExercisesManagerScreen), findsOneWidget);
  });

  testWidgets('Responsive rendering does not overflow on tablet/medium screens (720x850)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubjectUnderTest());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("Banque d'Exercices"), findsOneWidget);
  });
}
