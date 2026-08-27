import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import 'exercise_runner_screen.dart';

/// Second niveau du dossier « Exercices » (voir exercises_hub_screen.dart) : un chapitre par dossier.
/// Ouvrir un dossier chapitre mène directement au contenu (la liste d'exercices elle-même) — il n'y a
/// pas de troisième niveau utile, le contenu existe déjà à ce point.
class ExerciseChapterFoldersScreen extends StatelessWidget {
  final String subjectName;
  final List<Exercise> exercises;

  const ExerciseChapterFoldersScreen({super.key, required this.subjectName, required this.exercises});

  @override
  Widget build(BuildContext context) {
    final visual = SubjectVisuals.forSubject(name: subjectName);
    final byChapter = <String, List<Exercise>>{};
    for (final ex in exercises) {
      final key = ex.chapterTitle ?? 'Sans chapitre';
      byChapter.putIfAbsent(key, () => []).add(ex);
    }
    final chapterTitles = byChapter.keys.toList()..sort();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          subjectName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.colors.textPrimary, fontSize: 16),
        ),
      ),
      body: StudentPageContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: StudentScreenHeader(title: 'Chapitres — $subjectName'),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: chapterTitles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final chapterTitle = chapterTitles[index];
                  final items = byChapter[chapterTitle]!;
                  final linkedToLesson = items.any((e) => e.lessonId != null);
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseRunnerScreen(
                          chapterId: items.first.chapterId ?? '',
                          chapterTitle: chapterTitle,
                          preloadedExercises: items,
                        ),
                      ),
                    ),
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: visual.gradient.first.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.edit_note_rounded, color: visual.gradient.first, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapterTitle,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${items.length} exercice${items.length > 1 ? 's' : ''}',
                                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_forward_ios_rounded, color: context.colors.textSecondary, size: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
