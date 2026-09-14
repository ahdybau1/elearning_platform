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
import '../../../design_system/components/empty_state_view.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'exercise_chapter_folders_screen.dart';
import 'exercise_runner_screen.dart';
import '../../exercises/screens/exercise_path_screen.dart';
import '../../exercises/screens/variation_table_exercise_screen.dart';

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
          _buildInteractivePracticeBanner(context),
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
    return EmptyStateView(
      icon: Icons.edit_note_rounded,
      title: 'Aucun exercice publié pour le moment',
      description: 'Revenez bientôt : l\'enseignant prépare encore ce contenu d\'évaluation.',
    );
  }

  Widget _buildInteractivePracticeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PARCOURS & EXERCICES INTERACTIFS',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Entraînement adaptatif 6 niveaux & Tableaux',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSmall),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExercisePathScreen()),
                  );
                },
                icon: const Icon(Icons.alt_route_rounded, size: 16),
                label: const Text('Parcours 6 Niveaux', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSmall),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VariationTableExerciseScreen()),
                  );
                },
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Tableau de variations', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
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
      borderRadius: AppRadius.radiusLarge,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.radiusLarge,
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
                borderRadius: AppRadius.radiusMedium,
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
