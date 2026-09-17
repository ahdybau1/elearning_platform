import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/models/student_models.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'chapter_intro_screen.dart';
import '../../exercises/screens/exercise_path_screen.dart';
import '../../../core/models/summary_sheet_registry.dart';
import '../widgets/summary_sheet_viewer_modal.dart';

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
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 44,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Impossible de charger les chapitres',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vérifie ta connexion puis réessaie.',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(
                            studentChaptersProvider(
                              ChaptersQuery(
                                subjectId: subjectId,
                                classNodeId: classNodeId,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (chapters) {
                  if (chapters.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.auto_stories_outlined,
                      title: 'Aucun chapitre publié pour le moment',
                      description:
                          'Le contenu de $subjectName pour votre classe est en cours de préparation.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: chapters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return _ChapterItemCard(
                        chapter: chapter,
                        index: index,
                        visual: visual,
                        subjectName: subjectName,
                      );
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
        borderRadius: AppRadius.radiusXLarge,
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
                  borderRadius: AppRadius.radiusMedium,
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
}

/// Carte de chapitre interactive avec possibilité de déplier et sélectionner les leçons
class _ChapterItemCard extends ConsumerStatefulWidget {
  final Chapter chapter;
  final int index;
  final SubjectVisual visual;
  final String? subjectName;

  const _ChapterItemCard({
    required this.chapter,
    required this.index,
    required this.visual,
    this.subjectName,
  });

  @override
  ConsumerState<_ChapterItemCard> createState() => _ChapterItemCardState();
}

class _ChapterItemCardState extends ConsumerState<_ChapterItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final isUnlocked = chapter.isUnlocked;
    final summarySheet = SummarySheetRegistry.findSheetFor(chapter.title);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isUnlocked
            ? context.colors.card
            : context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(
          color: isUnlocked
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.4),
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Semantics(
        container: true,
        label: 'Chapitre ${widget.index + 1}, ${chapter.title}',
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: isUnlocked
                      ? LinearGradient(
                          colors: widget.visual.gradient,
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
                                  ? widget.visual.gradient.first.withValues(
                                      alpha: 0.18,
                                    )
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: AppRadius.radiusSmall,
                            ),
                            child: Text(
                              'Chapitre ${widget.index + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked
                                    ? widget.visual.gradient.first
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stat capsules
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surface.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: AppRadius.radiusSmall,
                                  border: Border.all(
                                    color: context.colors.border.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 13,
                                      color: widget.visual.gradient.first,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${chapter.lessonsCount} leçons',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surface.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: AppRadius.radiusSmall,
                                  border: Border.all(
                                    color: context.colors.border.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.quiz_rounded,
                                      size: 13,
                                      color: context.colors.accentEmerald,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${chapter.exercisesCount} exercices',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isUnlocked) ...[
                            // Secondary pill actions
                            Wrap(
                              spacing: 6,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        context.colors.textSecondary,
                                    backgroundColor: context.colors.surface
                                        .withValues(alpha: 0.5),
                                    side: BorderSide(
                                      color: context.colors.border,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChapterIntroScreen(
                                          chapterId: chapter.id,
                                          introduction: chapter.introduction,
                                          subjectName:
                                              (widget.subjectName ??
                                                      'MATHEMATIQUES')
                                                  .toUpperCase(),
                                          chapterTitle: chapter.title,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.history_edu_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Introduction',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        context.colors.textSecondary,
                                    backgroundColor: context.colors.surface
                                        .withValues(alpha: 0.5),
                                    side: BorderSide(
                                      color: context.colors.border,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ExercisePathScreen(
                                          subjectName:
                                              (widget.subjectName ??
                                                      'MATHEMATIQUES')
                                                  .toUpperCase(),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.alt_route_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Exercices',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (summarySheet != null)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          widget.visual.gradient.first,
                                      backgroundColor: widget
                                          .visual.gradient.first
                                          .withValues(alpha: 0.1),
                                      side: BorderSide(
                                        color: widget.visual.gradient.first
                                            .withValues(alpha: 0.35),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      SummarySheetViewerModal.show(
                                        context,
                                        summarySheet,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Fiche mémo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (chapter.lessonsCount > 1)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          context.colors.textSecondary,
                                      backgroundColor: context.colors.surface
                                          .withValues(alpha: 0.5),
                                      side: BorderSide(
                                        color: context.colors.border,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: Icon(
                                      _isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: context.colors.textSecondary,
                                      size: 16,
                                    ),
                                    onPressed: () => setState(
                                      () => _isExpanded = !_isExpanded,
                                    ),
                                    label: Text(
                                      _isExpanded ? 'Masquer' : 'Leçons',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Primary hero CTA button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.visual.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.visual.gradient.first
                                        .withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/lesson-reader',
                                      arguments: {
                                        'chapterId': chapter.id,
                                        'chapterTitle': chapter.title,
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ouvrir le cours',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surface.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.colors.border.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: context.colors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      chapter.termName != null
                                          ? 'Débloqué au ${chapter.termName}'
                                          : 'Bientôt disponible dans votre parcours',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: context.colors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Vue dépliée des leçons du chapitre pour accès 1-clic direct
                      if (isUnlocked && _isExpanded) ...[
                        const SizedBox(height: 16),
                        Divider(color: context.colors.border, height: 1),
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final lessonsAsync = ref.watch(
                              studentLessonsProvider(chapter.id),
                            );
                            return lessonsAsync.when(
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              error: (_, _) => Text(
                                'Leçons momentanément indisponibles.',
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              data: (lessons) {
                                if (lessons.isEmpty) {
                                  return Text(
                                    'Aucune leçon disponible pour l\'instant.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: context.colors.textMuted,
                                    ),
                                  );
                                }
                                return Column(
                                  children: lessons.asMap().entries.map((
                                    entry,
                                  ) {
                                    final idx = entry.key;
                                    final lesson = entry.value;
                                    return InkWell(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/lesson-reader',
                                          arguments: {
                                            'chapterId': chapter.id,
                                            'chapterTitle': chapter.title,
                                            'initialLessonId': lesson.id,
                                          },
                                        );
                                      },
                                      borderRadius: AppRadius.radiusSmall,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.play_circle_outline_rounded,
                                              size: 16,
                                              color:
                                                  widget.visual.gradient.first,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${idx + 1}. ${lesson.title}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: context
                                                      .colors
                                                      .textPrimary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${lesson.readingTimeMinutes} min',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: context.colors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
