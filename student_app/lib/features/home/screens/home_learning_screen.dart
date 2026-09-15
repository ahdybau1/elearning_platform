import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../subscription/screens/paywall_modal.dart';

/// Accueil v2 centré sur la prochaine action pédagogique.
/// Toutes les données affichées proviennent du profil et des providers existants.
class HomeLearningScreen extends ConsumerWidget {
  const HomeLearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(studentAuthProvider);
    final profile = auth.activeProfile;
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
            _Header(
              firstName: auth.account?.firstName ?? '',
              className: profile?.className ?? '',
            ),
            const SizedBox(height: 20),
            subjects.when(
              loading: () => const _LoadingCard(),
              error: (_, __) => _StateCard(
                icon: Icons.cloud_off_rounded,
                title: 'Impossible de charger les cours',
                message: 'Vérifie ta connexion puis tire vers le bas pour réessayer.',
                actionLabel: 'Réessayer',
                onAction: () =>
                    ref.invalidate(studentSubjectsProvider(classId)),
              ),
              data: (items) => items.isEmpty
                  ? const _StateCard(
                      icon: Icons.auto_stories_outlined,
                      title: 'Ton programme arrive bientôt',
                      message: 'Aucune matière n’est encore publiée pour cette classe.',
                    )
                  : _ContinueCard(
                      subject: items.first,
                      onTap: () => _openSubject(context, items.first, classId),
                    ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'Tes matières',
              action: 'Tout voir',
              onTap: () => _showAllSubjects(context),
            ),
            const SizedBox(height: 10),
            subjects.when(
              loading: () => const SizedBox(height: 110),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => _SubjectStrip(
                subjects: items,
                onTap: (subject) => _openSubject(context, subject, classId),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'À faire maintenant',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _QuickActions(
              onPractice: () => _selectMainTab(context, 2),
              onTutor: () => Navigator.of(context).pushNamed('/ai-tutor'),
              onProgress: () => _selectMainTab(context, 3),
            ),
            const SizedBox(height: 24),
            term.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (value) => value == null
                  ? const SizedBox.shrink()
                  : _TermCard(term: value),
            ),
            if (profile?.hasActiveSubscription != true) ...[
              const SizedBox(height: 16),
              _SubscriptionNote(onTap: () => PaywallModal.show(context)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openSubject(BuildContext context, Subject subject, String classId) {
    Navigator.of(context).pushNamed(
      '/chapters',
      arguments: {
        'subjectId': subject.id,
        'subjectName': subject.name,
        'subjectCode': subject.code,
        'classNodeId': classId,
      },
    );
  }

  void _showAllSubjects(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Utilise l’onglet Cours pour afficher toutes les matières.',
        ),
      ),
    );
  }

  void _selectMainTab(BuildContext context, int index) {
    Actions.invoke(context, MainTabIntent(index));
  }
}

/// Intent local permettant aux cartes de l'accueil de demander un changement
/// d'onglet sans dépendre de l'état interne du shell.
class MainTabIntent extends Intent {
  const MainTabIntent(this.index);
  final int index;
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.className});
  final String firstName;
  final String className;

  @override
  Widget build(BuildContext context) {
    final greeting = firstName.trim().isEmpty
        ? 'Bonjour'
        : 'Bonjour, $firstName';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                className.isEmpty
                    ? 'Prêt à apprendre ?'
                    : '$className • Que veux-tu apprendre ?',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tes notifications seront regroupées ici.'),
            ),
          ),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La recherche globale arrive dans la phase finale.',
              ),
            ),
          ),
          tooltip: 'Rechercher',
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.subject, required this.onTap});
  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = SubjectVisuals.forSubject(
      code: subject.code,
      name: subject.name,
    );
    return Material(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONTINUER À APPRENDRE',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: context.colors.accentPrimary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: visual.gradient.first.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(visual.icon, color: visual.gradient.first),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subject.chaptersCount == 0
                              ? 'Programme en préparation'
                              : '${subject.chaptersCount} chapitres disponibles',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class _SubjectStrip extends StatelessWidget {
  const _SubjectStrip({required this.subjects, required this.onTap});
  final List<Subject> subjects;
  final ValueChanged<Subject> onTap;
  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final visual = SubjectVisuals.forSubject(
            code: subject.code,
            name: subject.name,
          );
          return SizedBox(
            width: 144,
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => onTap(subject),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(visual.icon, color: visual.gradient.first),
                      const Spacer(),
                      Text(
                        subject.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onPractice,
    required this.onTutor,
    required this.onProgress,
  });
  final VoidCallback onPractice;
  final VoidCallback onTutor;
  final VoidCallback onProgress;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _QuickAction(
        icon: Icons.edit_note_rounded,
        label: 'M’entraîner',
        onTap: onPractice,
      ),
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: 'Demander au tuteur',
        onTap: onTutor,
      ),
      _QuickAction(
        icon: Icons.insights_rounded,
        label: 'Voir ma progression',
        onTap: onProgress,
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 19, color: context.colors.accentPrimary),
    label: Text(label),
    onPressed: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  );
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term});
  final TermInfo term;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term.termName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Avancement du calendrier scolaire',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: term.progressRatio.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SubscriptionNote extends StatelessWidget {
  const _SubscriptionNote({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        Icons.workspace_premium_outlined,
        color: context.colors.accentPrimary,
      ),
      title: const Text('Découvrir les formules pq learn'),
      subtitle: const Text('Compare clairement les contenus accessibles.'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 36, color: context.colors.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
