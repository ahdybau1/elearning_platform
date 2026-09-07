import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/core/models/summary_sheet_registry.dart';
import 'package:student_app/core/providers/student_providers.dart';
import 'package:student_app/core/theme/student_theme.dart';
import 'package:student_app/features/courses/screens/chapters_list_screen.dart';
import 'package:student_app/features/courses/screens/chapter_intro_screen.dart';
import 'package:student_app/features/courses/screens/derivative_lab_screen.dart';
import 'package:student_app/features/courses/screens/lesson_reader_screen.dart';
import 'package:student_app/features/courses/widgets/summary_sheet_viewer_modal.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
    'Leaving derivative lab keeps the selected lesson without fake validation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentLessonsProvider('chapter').overrideWith((ref) async {
              reads++;
              return [
                for (var i = 1; i <= 2; i++)
                  Lesson(
                    id: 'lesson-$i',
                    chapterId: 'chapter',
                    title: 'Leçon choisie $i',
                    contentJson: {},
                    isFree: true,
                  ),
              ];
            }),
          ],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const LessonReaderScreen(
              chapterId: 'chapter',
              chapterTitle: 'Dérivation',
              initialLessonId: 'lesson-2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Leçon 2 sur 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Laboratoire interactif de la dérivée'));
      await tester.pumpAndSettle();
      expect(find.byType(DerivativeLabScreen), findsOneWidget);
      await tester.ensureVisible(find.text('REVENIR AU COURS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REVENIR AU COURS'));
      await tester.pumpAndSettle();
      expect(find.byType(DerivativeLabScreen), findsNothing);
      expect(find.text('Leçon 2 sur 2'), findsOneWidget);
      expect(find.textContaining('Observation validée'), findsNothing);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final title in ['La photosynthèse', 'Pendule élastique']) {
    testWidgets('Reader and chapter list resolve the same reference for $title', (
      tester,
    ) async {
      viewport(tester, 390);
      final hasSheet = title == 'Pendule élastique';
      final lesson = Lesson.fromJson({
        'id': 'lesson',
        'chapter_id': 'chapter',
        'title': 'Leçon de contrôle',
        'content_json': {
          'blocks': [
            {'type': 'paragraph', 'body': 'Texte du cours.'},
          ],
        },
        'min_subscription_tier': 'gratuit',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentLessonsProvider(
              'chapter',
            ).overrideWith((ref) async => [lesson]),
          ],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: LessonReaderScreen(chapterId: 'chapter', chapterTitle: title),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Texte du cours.'), findsOneWidget);
      expect(
        find.byTooltip('Fiche Mémo Synthèse HD (Zoom & Formules)'),
        hasSheet ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('FICHE DE SYNTHÈSE HD'),
        hasSheet ? findsOneWidget : findsNothing,
      );
      expect(find.text('Résumé : Suites Réelles'), findsNothing);
      if (hasSheet) {
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        final modal = tester.widget<SummarySheetViewerModal>(
          find.byType(SummarySheetViewerModal),
        );
        expect(modal.sheet.id, 'physique-pendule-elastique-dynamique');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentChaptersProvider(
              const ChaptersQuery(subjectId: 'subject', classNodeId: 'class'),
            ).overrideWith(
              (ref) async => [
                Chapter.fromJson({
                  'id': 'chapter',
                  'subject_id': 'subject',
                  'title': title,
                }),
              ],
            ),
          ],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const ChaptersListScreen(
              subjectId: 'subject',
              subjectName: 'Sciences',
              classNodeId: 'class',
            ),
          ),
        ),
      );
      // The subject decoration animates continuously; wait for provider/layout,
      // not for the entire screen to stop scheduling frames.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byTooltip('Fiche Mémo Synthèse HD'),
        hasSheet ? findsOneWidget : findsNothing,
      );
      if (hasSheet) {
        await tester.tap(find.byTooltip('Fiche Mémo Synthèse HD'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SummarySheetViewerModal>(
                find.byType(SummarySheetViewerModal),
              )
              .sheet
              .id,
          'physique-pendule-elastique-dynamique',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [390.0, 800.0, 1400.0]) {
    for (final sheet in SummarySheetRegistry.sheets) {
      testWidgets('Structured reference ${sheet.id} fits $width', (
        tester,
      ) async {
        viewport(tester, width);
        await tester.pumpWidget(
          MaterialApp(
            theme: StudentTheme.darkTheme,
            home: SummarySheetViewerModal(sheet: sheet),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Formules & Définitions'));
        await tester.pumpAndSettle();
        expect(find.text(sheet.sections.first.title), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
      'Viewer reports offline limitation without claiming a save at $width',
      (tester) async {
        viewport(tester, width);
        await tester.pumpWidget(
          MaterialApp(
            theme: StudentTheme.darkTheme,
            home: SummarySheetViewerModal(
              sheet: SummarySheetRegistry.sheets.first,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Enregistrement hors ligne — à venir'));
        await tester.pumpAndSettle();
        expect(
          find.text('L’enregistrement hors ligne n’est pas encore disponible.'),
          findsOneWidget,
        );
        expect(
          find.text('Fiche de synthèse disponible hors-ligne.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Missing image reports an error while formulas remain available',
    (tester) async {
      viewport(tester, 390);
      final source = SummarySheetRegistry.sheets.first;
      final sheet = SummarySheet(
        id: source.id,
        title: source.title,
        subject: source.subject,
        chapterTag: source.chapterTag,
        imageAssetPath: 'assets/sheets/not-present.jpg',
        sections: source.sections,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: StudentTheme.darkTheme,
          home: SummarySheetViewerModal(sheet: sheet),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Image indisponible. Consultez l’onglet Formules & Définitions.',
        ),
        findsOneWidget,
      );
      expect(find.text('Image en cours de chargement...'), findsNothing);
      await tester.tap(find.text('Formules & Définitions'));
      await tester.pumpAndSettle();
      expect(find.text(source.sections.first.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (
      title: 'La photosynthèse',
      subject: 'SVT',
      introduction: null,
      template: false,
    ),
    (
      title: 'La photosynthèse',
      subject: 'SVT',
      introduction: 'Introduction validée du chapitre.',
      template: false,
    ),
    (
      title: 'Dérivation et étude des fonctions',
      subject: 'Mathématiques',
      introduction: null,
      template: true,
    ),
    (
      title: 'Dérivation et étude des fonctions',
      subject: 'Mathématiques',
      introduction: 'Introduction validée du chapitre.',
      template: false,
    ),
  ]) {
    testWidgets(
      'Introduction respects context and opens its actual chapter: $scenario',
      (tester) async {
        viewport(tester, 390);
        const chapterId = '5fd965cb-aef9-42e7-b754-5c3c0e554eb5';
        var reads = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studentLessonsProvider(chapterId).overrideWith((ref) async {
                reads++;
                return [];
              }),
            ],
            child: MaterialApp(
              theme: StudentTheme.darkTheme,
              home: ChapterIntroScreen(
                chapterId: chapterId,
                chapterTitle: scenario.title,
                subjectName: scenario.subject,
                introduction: scenario.introduction,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Introduction validée du chapitre.'),
          scenario.introduction == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.textContaining('Au XVIIᵉ siècle'),
          scenario.template ? findsOneWidget : findsNothing,
        );
        expect(find.textContaining('TERMINALE C & D'), findsNothing);
        final start = find.text('COMMENCER LA PREMIÈRE LEÇON');
        await tester.ensureVisible(start);
        await tester.pumpAndSettle();
        await tester.tap(start);
        await tester.pumpAndSettle();
        final reader = tester.widget<LessonReaderScreen>(
          find.byType(LessonReaderScreen),
        );
        expect(reader.chapterId, chapterId);
        expect(reader.chapterTitle, scenario.title);
        expect(reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
