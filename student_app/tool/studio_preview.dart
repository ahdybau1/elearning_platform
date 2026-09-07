// Local visual harness using the real Admin template and Student renderer.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/features/courses/screens/lesson_reader_screen.dart';
import 'package:student_app/core/models/content_block.dart';
import 'package:student_app/core/rendering/block_renderer_registry.dart';
import 'package:student_app/core/theme/student_theme.dart';
// This development-only entry point deliberately exercises the actual Admin template.
// ignore: avoid_relative_lib_imports
import '../../admin_app/lib/core/models/subject_template_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final chapter = Uri.base.queryParameters['chapter'];
  if (chapter != null && chapter.isNotEmpty) {
    await dotenv.load(fileName: '.env.public');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    runApp(
      ProviderScope(
        child: MaterialApp(
          theme: StudentTheme.darkTheme,
          home: Banner(
            message: 'TEST LOCAL',
            location: BannerLocation.topEnd,
            child: LessonReaderScreen(
              chapterId: chapter,
              chapterTitle: 'Vérification du lecteur public',
            ),
          ),
        ),
      ),
    );
    return;
  }
  final blocks = SubjectTemplate.standardTemplates.first
      .generateBlocks()
      .map((block) => ContentBlock.fromJson(block.toJson()))
      .toList();
  runApp(
    MaterialApp(
      theme: StudentTheme.darkTheme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Prévisualisation locale · fiche élève'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) => Column(
                    children: blocks
                        .map(
                          (block) =>
                              BlockRendererRegistry.build(context, block),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
