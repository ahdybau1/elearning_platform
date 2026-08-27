import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import 'exercise_runner_screen.dart';

/// §3.2 du cahier des charges : structure à trois niveaux d'indépendance (liés à une leçon, liés à
/// un chapitre hors leçon, indépendants) — vraies données depuis `exercises` (voir
/// StudentSupabaseService.fetchExercisesForClass), regroupées côté client sur lesson_id/chapter_id.
class ExercisesHubScreen extends ConsumerWidget {
  const ExercisesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final exercisesAsync = profile == null
        ? const AsyncValue<List<Exercise>>.data([])
        : ref.watch(classExercisesProvider(profile.classNodeId));

    return StudentPageContent(
      child: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Erreur : $err', style: TextStyle(color: context.colors.accentRose)),
        ),
        data: (exercises) {
          final byLesson = exercises.where((e) => e.lessonId != null).toList();
          final byChapter = exercises.where((e) => e.lessonId == null && e.chapterId != null).toList();
          final independent = exercises.where((e) => e.isIndependent).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StudentScreenHeader(title: 'Exercices (${profile?.className ?? ''})'),
              const SizedBox(height: 24),
              _buildSection(
                context,
                'Liés à une leçon',
                'Créés par l\'enseignant et/ou générés par l\'IA',
                byLesson,
                context.colors.accentPrimary,
              ),
              const SizedBox(height: 28),
              _buildSection(
                context,
                'Entraînement de chapitre',
                'Synthèse hors leçon précise, approfondissement',
                byChapter,
                context.colors.accentIndigo,
              ),
              const SizedBox(height: 28),
              _buildSection(
                context,
                'Indépendants (type examen)',
                'Mélange de chapitres, accessibles depuis cette page générale',
                independent,
                context.colors.accentAmber,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String subtitle,
    List<Exercise> items,
    Color accent,
  ) {
    // Regroupe par chapitre/leçon (un même chapitre peut avoir plusieurs exercices) pour retrouver
    // le rendu "série d'exercices" attendu plutôt qu'une ligne par question isolée.
    final groups = <String, List<Exercise>>{};
    for (final ex in items) {
      final key = ex.chapterTitle ?? (ex.isIndependent ? 'Exercices indépendants' : 'Sans titre');
      groups.putIfAbsent(key, () => []).add(ex);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.card.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              'Aucun exercice publié dans cette catégorie pour le moment.',
              style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
            ),
          )
        else
          ...groups.entries.map((entry) {
            final groupExercises = entry.value;
            final subjectName = groupExercises.first.subjectName;
            return Builder(
              builder: (context) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_note_rounded, color: accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                          ),
                          Text(
                            '${subjectName != null ? '$subjectName • ' : ''}${groupExercises.length} exercice${groupExercises.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseRunnerScreen(
                            chapterId: groupExercises.first.chapterId ?? '',
                            chapterTitle: entry.key,
                            preloadedExercises: groupExercises,
                          ),
                        ),
                      ),
                      child: const Text('Commencer'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
