import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/models/content_models.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/content_management/screens/lesson_builder_screen.dart';

class StudioService extends SupabaseService {
  StudioService()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int creates = 0;
  int updates = 0;
  bool fail = false;
  bool published = false;
  int submissions = 0;
  bool failSubmission = false;
  @override
  Future<void> submitLessonDraftForReview(String lessonId) async {
    expect(saved, isNotNull);
    if (failSubmission) throw StateError('Soumission indisponible');
    submissions++;
  }

  Map<String, dynamic>? saved;
  @override
  Future<List<Subject>> fetchSubjects({
    Set<String>? countryIds,
    bool includeInactive = false,
  }) async => [Subject(id: 's', name: 'Mathématiques', code: 'MATH')];
  @override
  Future<List<Chapter>> fetchChapters(
    String subjectId, {
    String? termId,
    String? classNodeId,
    bool includeInactive = false,
  }) async => [Chapter(id: 'c', subjectId: 's', title: 'Suites')];
  @override
  Future<List<Lesson>> fetchLessonsForChapter(
    String chapterId, {
    bool includeInactive = false,
  }) async => [];
  @override
  Future<Lesson?> createLesson({
    required String chapterId,
    required String title,
    required Map<String, dynamic> contentJson,
    required int displayOrder,
    String minSubscriptionTier = 'gratuit',
  }) async {
    if (fail) throw StateError('Réseau indisponible');
    creates++;
    saved = contentJson;
    return Lesson(
      id: 'saved',
      chapterId: chapterId,
      title: title,
      contentJson: contentJson,
    );
  }

  @override
  Future<Lesson?> getLesson(String id) async => Lesson(
    id: id,
    chapterId: 'c',
    title: 'Mon brouillon',
    isPublished: published,
    contentJson: {
      'source': 'scan-original',
      'blocks': [
        {'type': 'paragraph', 'body': 'Contenu conservé'},
      ],
    },
  );
  @override
  Future<void> updateLesson({
    required String id,
    String? title,
    Map<String, dynamic>? contentJson,
    String? minSubscriptionTier,
    bool? isActive,
    String? editedBy,
  }) async {
    updates++;
    saved = contentJson;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(
    WidgetTester tester,
    StudioService service, {
    String? id,
  }) async {
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supabaseServiceProvider.overrideWithValue(service)],
        child: MaterialApp(home: LessonBuilderScreen(initialLessonId: id)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saveNew(WidgetTester tester, {bool submit = false}) async {
    await tester.tap(
      find.text(submit ? 'Soumettre pour validation' : 'Enregistrer'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Mathématiques (MATH)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Suites\nClasse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Studio actions fit a mobile viewport', (tester) async {
    final service = StudioService();
    await open(tester, service, id: 'existing');
    tester.view.physicalSize = const Size(390, 1000);
    await tester.pump();
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Soumettre pour validation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Submission saves first and failure retry does not duplicate the draft',
    (tester) async {
      final service = StudioService()..failSubmission = true;
      await open(tester, service);
      await saveNew(tester, submit: true);
      expect(service.creates, 1);
      expect(service.submissions, 0);
      service.failSubmission = false;
      await tester.tap(find.text('Soumettre pour validation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.creates, 1);
      expect(service.submissions, 1);
      expect(
        find.text('Brouillon enregistré et soumis pour validation.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Published content cannot be overwritten from the Studio', (
    tester,
  ) async {
    final service = StudioService()..published = true;
    await open(tester, service, id: 'published');
    expect(
      find.textContaining('Ouvrez cette leçon dans Leçons & Cours'),
      findsOneWidget,
    );
    expect(find.text('Enregistrer'), findsNothing);
    expect(service.updates, 0);
  });
  testWidgets('Creates once, then updates the same draft', (tester) async {
    final service = StudioService();
    await open(tester, service);
    await saveNew(tester);
    expect(service.creates, 1);
    expect(service.saved!['blocks'], isNotEmpty);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.creates, 1);
    expect(service.updates, 1);
  });
  testWidgets('Loads existing content and preserves source metadata', (
    tester,
  ) async {
    final service = StudioService();
    await open(tester, service, id: 'existing');
    expect(find.text('Mon brouillon'), findsWidgets);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.saved!['source'], 'scan-original');
    expect(
      (service.saved!['blocks'] as List).single['body'],
      'Contenu conservé',
    );
    expect(service.creates, 0);
  });
  testWidgets('Cancellation does not report a save', (tester) async {
    final service = StudioService();
    await open(tester, service);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    Navigator.of(tester.element(find.byType(SimpleDialog))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.creates, 0);
    expect(find.textContaining('enregistrée avec succès'), findsNothing);
  });
  testWidgets('Failed creation reports an error without success', (
    tester,
  ) async {
    final service = StudioService()..fail = true;
    await open(tester, service);
    await saveNew(tester);
    expect(find.textContaining('Échec de l’enregistrement'), findsOneWidget);
    expect(find.textContaining('enregistrée avec succès'), findsNothing);
  });
}
