import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_app/core/models/content_models.dart';
import 'package:admin_app/core/models/curriculum_preview_data.dart';
import 'package:admin_app/core/models/curriculum_models.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/engines/capability_registry.dart';
import 'package:admin_app/core/engines/engine_diagnostics.dart';
import 'package:admin_app/core/engines/image_generation_engine.dart';
import 'package:admin_app/features/content_management/screens/media_library_screen.dart';
import 'package:admin_app/features/content_management/widgets/media_attachment_picker.dart';
import 'package:admin_app/features/academic_tree/screens/curriculum_autopilot_screen.dart';
import 'package:admin_app/features/system_settings/screens/engine_center_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final asset = MediaAsset(
    id: 'media-1',
    filename: 'Cours enregistré.pdf',
    type: 'document',
    url: 'https://example.org/cours.pdf',
    uploadedBy: 'admin',
  );
  Widget host(Widget child, {Future<List<MediaAsset>> Function()? load}) =>
      ProviderScope(
        overrides: [
          mediaLibraryProvider(
            null,
          ).overrideWith((ref) => load?.call() ?? Future.value([asset])),
          // Écran « Collecte des Programmes » : liste d'imports vide en test (pas d'appel réseau).
          curriculumImportsProvider
              .overrideWith((ref) => Future.value(<CurriculumImport>[])),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: child),
      );

  for (final width in [345.0, 390.0, 800.0, 1400.0]) {
    for (final entry in <String, Widget>{
      'media': const MediaLibraryScreen(),
      'autopilot': const CurriculumAutopilotScreen(),
      'engines': const EngineCenterScreen(),
    }.entries) {
      testWidgets('${entry.key} works at width $width without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(entry.value));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('100%'), findsNothing);
        if (entry.key == 'media') {
          await tester.scrollUntilVisible(
            find.text(asset.filename),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(asset.filename), findsOneWidget);
          expect(find.text('Insérer dans le cours'), findsNothing);
        }
      });
    }
  }
  testWidgets('Library shows loading, then failure and recovers on retry', (
    tester,
  ) async {
    final completer = Completer<List<MediaAsset>>();
    var loads = 0;
    await tester.pumpWidget(
      host(
        const MediaLibraryScreen(),
        load: () => ++loads == 1 ? completer.future : Future.value([asset]),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger la médiathèque.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text(asset.filename), findsOneWidget);
  });
  testWidgets(
    'Library searches persisted files and filters their actual type',
    (tester) async {
      await tester.pumpWidget(host(const MediaLibraryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun fichier ne correspond à ces filtres.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Documents'));
      await tester.enterText(find.byType(TextField), '  enregistré  ');
      await tester.pumpAndSettle();
      expect(find.text(asset.filename), findsOneWidget);
    },
  );
  testWidgets('Copy writes the actual URL before reporting success', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(host(const MediaLibraryScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copier l’URL'));
    await tester.tap(find.text('Copier l’URL'));
    await tester.pumpAndSettle();
    expect(copied, asset.url);
    expect(find.text('URL copiée dans le presse-papier.'), findsOneWidget);
  });
  testWidgets('Existing media is returned to the content editor once', (
    tester,
  ) async {
    List<MediaAsset> selected = [];
    await tester.pumpWidget(
      host(
        Scaffold(
          body: MediaAttachmentPicker(onChanged: (items) => selected = items),
        ),
      ),
    );
    await tester.tap(find.text('Choisir dans la médiathèque'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sélectionner'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    expect(selected.map((item) => item.id), [asset.id]);
    expect(find.text(asset.filename), findsOneWidget);
  });
  test('Unconnected generation cannot return a fabricated image', () async {
    await expectLater(
      ImageGenerationEngine.generate(
        const ImageGenerationRequest(prompt: 'Cellule', subject: 'SVT'),
      ),
      throwsUnsupportedError,
    );
  });
  test(
    'Diagnostics distinguish checked local code from untested integration',
    () {
      for (final type in [
        CapabilityType.latex,
        CapabilityType.plot2d,
        CapabilityType.physicsSimulation,
        CapabilityType.circuitSimulation,
        CapabilityType.molecular3d,
      ]) {
        final result = EngineDiagnostics.run(type);
        expect(result.checked, isTrue);
        expect(result.passed, isTrue);
      }
      for (final type in [
        CapabilityType.codeExecution,
        CapabilityType.imageGeneration,
        CapabilityType.imageVisionOcr,
        CapabilityType.pedagogicalStructuring,
      ]) {
        final result = EngineDiagnostics.run(type);
        expect(result.checked, isFalse);
        expect(result.passed, isFalse);
      }
    },
  );
  test('Preserved sample does not certify any curriculum node', () {
    void check(List<CurriculumCandidateNode> nodes) {
      for (final node in nodes) {
        expect(node.isOfficial, isFalse);
        check(node.children);
      }
    }

    check(sampleCurriculum());
  });
}
