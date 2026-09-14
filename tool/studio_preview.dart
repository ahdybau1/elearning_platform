// Local visual harness; excluded from the production entry point.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/models/content_models.dart';
import 'package:admin_app/core/models/subject_template_model.dart';
import 'package:admin_app/core/providers/data_providers.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/content_management/screens/lesson_builder_screen.dart';

class PreviewService extends SupabaseService {
  PreviewService()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'preview',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  Future<Lesson?> getLesson(String id) async => Lesson(
    id: id,
    chapterId: 'preview',
    title: 'Suites réelles — fiche de synthèse',
    contentJson: {
      'version': 2,
      'blocks': SubjectTemplate.standardTemplates.first
          .generateBlocks()
          .map((b) => b.toJson())
          .toList(),
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
    throw StateError('Prévisualisation locale : écriture désactivée.');
  }
}

void main() => runApp(
  ProviderScope(
    overrides: [supabaseServiceProvider.overrideWithValue(PreviewService())],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Prévisualisation locale · écriture désactivée'),
        ),
        body: const LessonBuilderScreen(initialLessonId: 'preview'),
      ),
    ),
  ),
);
