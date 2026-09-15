import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// Catalogue des matières de la classe active, sans données simulées.
class SubjectsListScreen extends ConsumerStatefulWidget {
  const SubjectsListScreen({super.key});

  @override
  ConsumerState<SubjectsListScreen> createState() => _SubjectsListScreenState();
}

class _SubjectsListScreenState extends ConsumerState<SubjectsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final provider = studentSubjectsProvider(profile.classNodeId);
    final subjectsAsync = ref.watch(provider);

    return StudentPageContent(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _CatalogHeader(
                  className: profile.className,
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
            ),
            subjectsAsync.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => SliverFillRemaining(
                hasScrollBody: false,
                child: _LoadError(onRetry: () => ref.invalidate(provider)),
              ),
              data: (subjects) {
                final filtered = filterSubjects(subjects, _query);
                if (subjects.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.menu_book_outlined,
                      title: 'Aucune matière pour ${profile.className}',
                      description: 'Les matières apparaîtront dès que le programme de cette classe sera publié.',
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'Aucune matière trouvée',
                      description:
                          'Essaie un autre nom ou efface la recherche.',
                    ),
                  );
                }
                return _SubjectGrid(
                  subjects: filtered,
                  classNodeId: profile.classNodeId,
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
List<Subject> filterSubjects(List<Subject> subjects, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return subjects;
  return subjects
      .where(
        (subject) =>
            subject.name.toLowerCase().contains(normalized) ||
            subject.code.toLowerCase().contains(normalized),
      )
      .toList(growable: false);
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.className,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final String className;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cours', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          className.isEmpty
              ? 'Explore toutes les matières de ton programme.'
              : '$className • Explore toutes les matières de ton programme.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: 18),
        Semantics(
          textField: true,
          label: 'Rechercher une matière',
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Rechercher une matière',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        onPressed: onClear,
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectGrid extends StatelessWidget {
  const _SubjectGrid({required this.subjects, required this.classNodeId});

  final List<Subject> subjects;
  final String classNodeId;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 3 : (width >= 680 ? 2 : 1);

    return SliverPadding(
      padding: AppSpacing.pagePaddingMobile,
      sliver: SliverGrid.builder(
        itemCount: subjects.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.15 : 2.15,
        ),
        itemBuilder: (context, index) =>
            _SubjectCard(subject: subjects[index], classNodeId: classNodeId),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.classNodeId});

  final Subject subject;
  final String classNodeId;

  @override
  Widget build(BuildContext context) {
    final visual = SubjectVisuals.forSubject(
      code: subject.code,
      name: subject.name,
    );
    return Semantics(
      button: true,
      label: 'Ouvrir ${subject.name}',
      child: Material(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
        child: InkWell(
          borderRadius: AppRadius.radiusLarge,
          onTap: () => Navigator.of(context).pushNamed(
            '/chapters',
            arguments: {
              'subjectId': subject.id,
              'subjectName': subject.name,
              'subjectCode': subject.code,
              'classNodeId': classNodeId,
            },
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusLarge,
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: visual.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                  child: Icon(visual.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subject.chaptersCount == 0
                            ? 'Programme en préparation'
                            : '${subject.chaptersCount} chapitres',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.cardPadding,
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
              'Impossible de charger les matières',
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
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
