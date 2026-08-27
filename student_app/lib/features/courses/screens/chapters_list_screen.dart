import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/models/student_models.dart';

class ChaptersListScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;
  final String classNodeId;
  final String? subjectCode;

  const ChaptersListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.classNodeId,
    this.subjectCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(
      studentChaptersProvider(
        ChaptersQuery(subjectId: subjectId, classNodeId: classNodeId),
      ),
    );
    final visual = SubjectVisuals.forSubject(
      code: subjectCode,
      name: subjectName,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          subjectName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: StudentPageContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: _buildHeroBanner(visual),
            ),
            Expanded(
              child: chaptersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    'Erreur: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (chapters) {
                  if (chapters.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 46,
                              color: context.colors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun chapitre publié pour le moment',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Le contenu de $subjectName pour votre classe est en cours de préparation.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: chapters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return _buildChapterCard(context, chapter, index, visual);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(SubjectVisual visual) {
    return Container(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: visual.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: visual.gradient.last.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -20,
            child: SubjectMotif(icon: visual.icon, size: 130, opacity: 0.14),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Programme officiel — déblocage progressif par trimestre',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(
    BuildContext context,
    Chapter chapter,
    int index,
    SubjectVisual visual,
  ) {
    final isUnlocked = chapter.isUnlocked;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isUnlocked
            ? context.colors.card
            : context.colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.4),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                gradient: isUnlocked
                    ? LinearGradient(
                        colors: visual.gradient,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: isUnlocked ? null : context.colors.border,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? visual.gradient.first.withValues(alpha: 0.18)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Chapitre ${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked
                                  ? visual.gradient.first
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        if (!isUnlocked)
                          Row(
                            children: [
                              Icon(
                                Icons.lock_clock_rounded,
                                size: 14,
                                color: context.colors.accentAmber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                chapter.termName ?? 'À venir',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: context.colors.accentAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 14,
                                color: context.colors.accentEmerald,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Disponible',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: context.colors.accentEmerald,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      chapter.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked
                            ? context.colors.textPrimary
                            : context.colors.textSecondary,
                      ),
                    ),
                    if (chapter.introduction != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        chapter.introduction!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${chapter.lessonsCount} leçons • ${chapter.exercisesCount} exercices',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                        if (isUnlocked)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: visual.gradient.first,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/lesson-reader',
                                arguments: {
                                  'chapterId': chapter.id,
                                  'chapterTitle': chapter.title,
                                },
                              );
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Ouvrir le cours',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.textSecondary,
                              side: BorderSide(color: context.colors.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    chapter.termName != null
                                        ? 'Ce chapitre sera débloqué automatiquement au ${chapter.termName}.'
                                        : 'Ce chapitre sera débloqué automatiquement à la date prévue.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Bientôt débloqué',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
