import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import 'exercise_chapter_folders_screen.dart';
import 'exercise_runner_screen.dart';

/// §3.2 du CDC : vraies données (StudentSupabaseService.fetchExercisesForClass). Navigation en vrais
/// dossiers qu'on ouvre l'un après l'autre — matière, puis chapitre, puis le contenu lui-même —
/// exactement comme Mes Matières & Cours, plutôt qu'une longue page qui étale tout d'un coup (un
/// premier essai qui groupait par la distinction technique admin lié-leçon/lié-chapitre/indépendant
/// a été jugé inutilisable ; un second qui affichait tout à plat aussi). Un dossier n'apparaît que
/// s'il contient déjà quelque chose.
class ExercisesHubScreen extends ConsumerWidget {
  const ExercisesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final exercisesAsync = profile == null
        ? const AsyncValue<List<Exercise>>.data([])
        : ref.watch(classExercisesProvider(profile.classNodeId));

    return StudentPageContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: StudentScreenHeader(title: 'Exercices (${profile?.className ?? ''})'),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur : $err', style: TextStyle(color: context.colors.accentRose)),
              ),
              data: (exercises) {
                if (exercises.isEmpty) return _emptyState(context);

                final independent = exercises.where((e) => e.isIndependent).toList();
                final bySubject = <String, List<Exercise>>{};
                for (final ex in exercises.where((e) => !e.isIndependent)) {
                  final subject = ex.subjectName ?? 'Autre';
                  bySubject.putIfAbsent(subject, () => []).add(ex);
                }
                final subjectNames = bySubject.keys.toList()..sort();

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: subjectNames.length + (independent.isEmpty ? 0 : 1),
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index < subjectNames.length) {
                      final subject = subjectNames[index];
                      final items = bySubject[subject]!;
                      final chapterCount = items.map((e) => e.chapterTitle ?? e.chapterId).toSet().length;
                      return _FolderCard(
                        visual: SubjectVisuals.forSubject(name: subject),
                        title: subject,
                        subtitle: '$chapterCount chapitre${chapterCount > 1 ? 's' : ''} • ${items.length} exercice${items.length > 1 ? 's' : ''}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExerciseChapterFoldersScreen(subjectName: subject, exercises: items),
                          ),
                        ),
                      );
                    }
                    // Dossier « Exercices transversaux » : pas de sous-dossier chapitre pertinent,
                    // il ouvre directement le contenu (voir la même logique en bout de chaîne côté
                    // ExerciseChapterFoldersScreen).
                    return _FolderCard(
                      visual: SubjectVisual(icon: Icons.shuffle_rounded, gradient: const [Color(0xFFB45309), Color(0xFFD97706)]),
                      title: 'Exercices transversaux',
                      subtitle: '${independent.length} exercice${independent.length > 1 ? 's' : ''} • plusieurs chapitres',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseRunnerScreen(
                            chapterId: '',
                            chapterTitle: 'Exercices transversaux',
                            preloadedExercises: independent,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded, size: 46, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Aucun exercice publié pour le moment',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Revenez bientôt : l\'enseignant prépare encore ce contenu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte "dossier" partagée entre ce hub et ExerciseChapterFoldersScreen — même style visuel que les
/// cartes matière de subjects_list_screen.dart, pour une navigation cohérente dans toute l'app.
class _FolderCard extends StatelessWidget {
  final SubjectVisual visual;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FolderCard({required this.visual, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: visual.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: visual.gradient.last.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Stack(
                children: [
                  Positioned(right: -8, bottom: -8, child: SubjectMotif(icon: visual.icon, size: 42, opacity: 0.22)),
                  Center(child: Icon(visual.icon, color: Colors.white, size: 24)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
              child: Icon(Icons.arrow_forward_ios_rounded, color: context.colors.textSecondary, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
