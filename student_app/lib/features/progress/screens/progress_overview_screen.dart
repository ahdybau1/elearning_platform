import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// Vue de progression fondée uniquement sur les données réellement disponibles.
/// Les indicateurs de maîtrise/XP ne sont pas inventés tant que leur agrégat
/// backend n'existe pas.
class ProgressOverviewScreen extends ConsumerWidget {
  const ProgressOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final classId = profile?.classNodeId ?? '';
    final subjects = ref.watch(studentSubjectsProvider(classId));
    final term = ref.watch(currentTermInfoProvider(classId));

    return StudentPageContent(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentSubjectsProvider(classId));
          ref.invalidate(currentTermInfoProvider(classId));
        },
        child: ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            Text(
              'Progression',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Une vue claire de ton programme et de ce qu’il reste à consolider.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 20),
            term.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (value) => value == null
                  ? const SizedBox.shrink()
                  : _ProgrammeCard(
                      label: value.termName,
                      schoolYear:
                          value.schoolYearName ?? profile?.schoolYear ?? '',
                      progress: value.progressRatio,
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mes matières',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: () =>
                      ref.invalidate(studentSubjectsProvider(classId)),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            subjects.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => _InfoCard(
                icon: Icons.cloud_off_rounded,
                title: 'Progression indisponible',
                message: 'Les données n’ont pas pu être chargées. Tire vers le bas pour réessayer.',
              ),
              data: (items) => items.isEmpty
                  ? const _InfoCard(
                      icon: Icons.auto_stories_outlined,
                      title: 'Aucune matière disponible',
                      message: 'Les matières apparaîtront ici dès que le programme sera publié.',
                    )
                  : Column(
                      children: items
                          .map(
                            (subject) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                minVerticalPadding: 14,
                                leading: CircleAvatar(
                                  backgroundColor: context.colors.accentPrimary
                                      .withValues(alpha: .12),
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    color: context.colors.accentPrimary,
                                  ),
                                ),
                                title: Text(subject.name),
                                subtitle: Text(
                                  subject.chaptersCount == 0
                                      ? 'Programme en préparation'
                                      : '${subject.chaptersCount} chapitres au programme',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
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
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            const _InfoCard(
              icon: Icons.insights_rounded,
              title: 'Maîtrise et séries de travail',
              message: 'Les scores de maîtrise, le temps d’étude et les séries seront affichés dès que leur agrégation sera disponible. Aucune valeur fictive n’est présentée.',
            ),
            const SizedBox(height: 24),
          ],
        ),
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
