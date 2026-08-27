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

/// §3.2 du CDC : vraies données (voir StudentSupabaseService.fetchExercisesForClass). Groupé par
/// MATIÈRE puis CHAPITRE — c'est ainsi qu'un élève cherche un exercice (« je veux faire des maths »,
/// jamais « je veux les exercices liés-à-une-leçon »), pas par la distinction technique interne
/// lié-à-leçon / lié-à-chapitre / indépendant utilisée côté admin pour la création. Cette dernière
/// reste visible mais reléguée à une petite étiquette sur chaque série, pas à la structure entière de
/// la page (retour direct d'un premier essai qui organisait tout par cette distinction — jugé
/// inutilisable par l'utilisateur : « ça n'aide en rien »).
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
          if (exercises.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                StudentScreenHeader(title: 'Exercices (${profile?.className ?? ''})'),
                const SizedBox(height: 24),
                _emptyState(context),
              ],
            );
          }

          final independent = exercises.where((e) => e.isIndependent).toList();
          final bySubject = <String, List<Exercise>>{};
          for (final ex in exercises.where((e) => !e.isIndependent)) {
            final subject = ex.subjectName ?? 'Autre';
            bySubject.putIfAbsent(subject, () => []).add(ex);
          }
          final subjectNames = bySubject.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StudentScreenHeader(title: 'Exercices (${profile?.className ?? ''})'),
              const SizedBox(height: 24),
              for (final subject in subjectNames) ...[
                _buildSubjectSection(context, subject, bySubject[subject]!),
                const SizedBox(height: 24),
              ],
              if (independent.isNotEmpty)
                _buildIndependentSection(context, independent),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.edit_note_rounded, color: context.colors.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            'Aucun exercice publié pour votre classe pour le moment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSection(BuildContext context, String subject, List<Exercise> items) {
    // Regroupe par chapitre (un même chapitre peut porter plusieurs exercices, liés ou non à une
    // leçon précise — cette nuance passe en petite étiquette sur la carte, voir _buildExerciseCard).
    final byChapter = <String, List<Exercise>>{};
    for (final ex in items) {
      final key = ex.chapterTitle ?? 'Sans chapitre';
      byChapter.putIfAbsent(key, () => []).add(ex);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 18, color: context.colors.accentPrimary),
            const SizedBox(width: 8),
            Text(
              subject,
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...byChapter.entries.map((entry) => _buildExerciseCard(
              context,
              title: entry.key,
              items: entry.value,
              accent: context.colors.accentPrimary,
            )),
      ],
    );
  }

  Widget _buildIndependentSection(BuildContext context, List<Exercise> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shuffle_rounded, size: 18, color: context.colors.accentAmber),
            const SizedBox(width: 8),
            Text(
              'Exercices transversaux',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Mélange de plusieurs chapitres, type révision d\'examen — pas rattachés à une seule matière.',
          style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 12),
        _buildExerciseCard(
          context,
          title: 'Série transversale',
          items: items,
          accent: context.colors.accentAmber,
        ),
      ],
    );
  }

  Widget _buildExerciseCard(
    BuildContext context, {
    required String title,
    required List<Exercise> items,
    required Color accent,
  }) {
    // Étiquette discrète de la distinction technique admin (§3.2) — visible pour qui s'y intéresse,
    // sans dicter la structure de la page.
    final linkedToLesson = items.any((e) => e.lessonId != null);
    return Container(
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
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                ),
                Row(
                  children: [
                    Text(
                      '${items.length} exercice${items.length > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                    ),
                    if (linkedToLesson) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'lié à une leçon',
                          style: GoogleFonts.inter(fontSize: 9, color: context.colors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseRunnerScreen(
                  chapterId: items.first.chapterId ?? '',
                  chapterTitle: title,
                  preloadedExercises: items,
                ),
              ),
            ),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }
}
