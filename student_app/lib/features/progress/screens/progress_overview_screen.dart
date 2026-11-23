import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../courses/screens/exercise_runner_screen.dart';

/// Progression de l'élève, uniquement à partir de ses vraies traces :
/// leçons marquées lues (`lesson_completions`), dernier essai par exercice (`exercise_attempts`),
/// compétences liées aux exercices (`get_student_skill_mastery`). Aucun score inventé.
class ProgressOverviewScreen extends ConsumerWidget {
  const ProgressOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final classId = profile?.classNodeId ?? '';
    final profileId = profile?.id ?? '';
    final subjects = ref.watch(studentSubjectsProvider(classId));
    final term = ref.watch(currentTermInfoProvider(classId));
    final exercises = ref.watch(classExercisesProvider(classId)).valueOrNull ?? const <Exercise>[];
    final results = ref.watch(exerciseResultsProvider(profileId)).valueOrNull ?? const <String, bool?>{};
    final lessonKey = (profileId: profileId, classNodeId: classId);
    final lessonStats = ref.watch(lessonStatsProvider(lessonKey)).valueOrNull ?? const {};
    final weakSkills = ref.watch(weakSkillsProvider(profileId)).valueOrNull ?? const [];

    final tried = exercises.where((e) => results.containsKey(e.id)).toList();
    final succeeded = tried.where((e) => results[e.id] != false).length;
    final toReview = tried.where((e) => results[e.id] == false).toList();
    final lessonsDone = lessonStats.values.fold<int>(0, (a, b) => a + b.done);
    final lessonsTotal = lessonStats.values.fold<int>(0, (a, b) => a + b.total);

    return StudentPageContent(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentSubjectsProvider(classId));
          ref.invalidate(currentTermInfoProvider(classId));
          ref.invalidate(classExercisesProvider(classId));
          ref.invalidate(exerciseResultsProvider(profileId));
          ref.invalidate(lessonStatsProvider(lessonKey));
          ref.invalidate(weakSkillsProvider(profileId));
        },
        child: ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            Text('Progression', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Ce que tu as déjà fait et ce qu\'il reste à consolider.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Stat(value: '$lessonsDone/$lessonsTotal', label: 'leçons lues')),
                const SizedBox(width: 10),
                Expanded(child: _Stat(value: '$succeeded/${tried.length}', label: 'exercices réussis')),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    value: '${toReview.length}',
                    label: 'à revoir',
                    highlight: toReview.isNotEmpty,
                  ),
                ),
              ],
            ),
            if (toReview.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseRunnerScreen(
                      chapterId: '',
                      chapterTitle: 'Exercices à revoir',
                      preloadedExercises: toReview,
                    ),
                  ),
                ).then((_) => ref.invalidate(exerciseResultsProvider(profileId))),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: Text('Refaire mes ${toReview.length} exercice${toReview.length > 1 ? 's' : ''} ratés'),
              ),
            ],
            const SizedBox(height: 16),
            term.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (value) => value == null
                  ? const SizedBox.shrink()
                  : _ProgrammeCard(
                      label: value.termName,
                      schoolYear: value.schoolYearName ?? profile?.schoolYear ?? '',
                      progress: value.progressRatio,
                    ),
            ),
            if (weakSkills.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('À consolider', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in weakSkills)
                    Chip(
                      avatar: Icon(Icons.trending_down_rounded, size: 16, color: context.colors.accentRose),
                      label: Text('${w.name} · ${(w.mastery * 100).round()} %'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('Mes matières', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            subjects.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
              ),
              error: (error, _) => const _InfoCard(
                icon: Icons.cloud_off_rounded,
                title: 'Progression indisponible',
                message: 'Les données n\'ont pas pu être chargées. Tire vers le bas pour réessayer.',
              ),
              data: (items) => items.isEmpty
                  ? const _InfoCard(
                      icon: Icons.auto_stories_outlined,
                      title: 'Aucune matière disponible',
                      message: 'Les matières apparaîtront ici dès que le programme sera publié.',
                    )
                  : Column(
                      children: [
                        for (final subject in items)
                          _SubjectProgress(
                            subject: subject,
                            lessons: lessonStats[subject.id],
                            exercises: exercises.where((e) => e.subjectName == subject.name).toList(),
                            results: results,
                            onTap: () => Navigator.of(context).pushNamed(
                              '/chapters',
                              arguments: {
                                'subjectId': subject.id,
                                'subjectName': subject.name,
                                'subjectCode': subject.code,
                                'classNodeId': classId,
                              },
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.highlight = false});

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? context.colors.accentRose : context.colors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SubjectProgress extends StatelessWidget {
  const _SubjectProgress({
    required this.subject,
    required this.lessons,
    required this.exercises,
    required this.results,
    required this.onTap,
  });

  final Subject subject;
  final ({int done, int total})? lessons;
  final List<Exercise> exercises;
  final Map<String, bool?> results;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tried = exercises.where((e) => results.containsKey(e.id)).toList();
    final ok = tried.where((e) => results[e.id] != false).length;
    final lessonTotal = lessons?.total ?? 0;
    final lines = <Widget>[
      if (lessonTotal > 0)
        _bar(context, 'Leçons', lessons!.done, lessonTotal, context.colors.accentPrimary),
      if (exercises.isNotEmpty)
        _bar(context, 'Exercices réussis', ok, exercises.length, context.colors.accentEmerald),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    if (lines.isEmpty)
                      Text(
                        subject.chaptersCount == 0
                            ? 'Programme en préparation'
                            : '${subject.chaptersCount} chapitre${subject.chaptersCount > 1 ? 's' : ''} au programme',
                        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                      )
                    else
                      ...lines,
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, String label, int value, int total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : value / total,
                minHeight: 6,
                backgroundColor: context.colors.surface,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value/$total', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({
    required this.label,
    required this.schoolYear,
    required this.progress,
  });

  final String label;
  final String schoolYear;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: context.colors.accentPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (schoolYear.isNotEmpty) Text(schoolYear),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress.clamp(0, 1) * 100).round()} % de la période écoulée',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
