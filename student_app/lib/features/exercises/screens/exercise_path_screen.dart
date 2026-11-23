import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../courses/screens/exercise_runner_screen.dart';

/// Parcours progressif d'une matière, construit uniquement sur les vraies données :
/// - les niveaux sont les difficultés réellement saisies par l'admin sur les exercices publiés
///   pour la classe de l'élève (facile → intermédiaire → approfondissement) ;
/// - la progression vient de ses tentatives enregistrées (`exercise_attempts`), dernier essai par
///   exercice.
/// Un niveau s'ouvre quand l'élève a réussi au moins 60 % du niveau précédent ; il est « maîtrisé »
/// à 80 %. Rien n'est affiché qui ne vienne de la base (l'ancienne maquette montrait un niveau 3 et
/// des seuils « 12/15 » identiques pour tout le monde).
class ExercisePathScreen extends ConsumerWidget {
  final String subjectName;
  final List<Exercise> exercises;

  const ExercisePathScreen({
    super.key,
    required this.subjectName,
    required this.exercises,
  });

  static const unlockRatio = 0.6;
  static const masteryRatio = 0.8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final resultsAsync = profile == null
        ? const AsyncValue<Map<String, bool?>>.data({})
        : ref.watch(exerciseResultsProvider(profile.id));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Parcours — $subjectName',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
      body: StudentPageContent(
        child: resultsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _message(
            context,
            'Impossible de charger ta progression pour le moment.',
            onRetry: profile == null
                ? null
                : () => ref.invalidate(exerciseResultsProvider(profile.id)),
          ),
          data: (results) {
            final levels = buildLevels(exercises, results);
            if (levels.isEmpty) {
              return _message(context, 'Aucun exercice publié dans cette matière pour ta classe.');
            }
            final current = levels.indexWhere((l) => l.unlocked && !l.mastered);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  current == -1
                      ? 'Tous les niveaux sont maîtrisés. Bravo, tu peux refaire ceux de ton choix.'
                      : 'Tu en es au niveau ${current + 1} sur ${levels.length}.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Un niveau s\'ouvre quand tu réussis au moins 60 % du précédent.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                ),
                const SizedBox(height: 18),
                for (final (i, level) in levels.indexed) ...[
                  _LevelCard(
                    level: level,
                    number: i + 1,
                    isCurrent: i == current,
                    previousLabel: i == 0 ? null : levels[i - 1].label,
                    onOpen: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseRunnerScreen(
                            chapterId: '',
                            chapterTitle: '$subjectName · ${level.label}',
                            preloadedExercises: level.orderedExercises,
                          ),
                        ),
                      );
                      if (profile != null) ref.invalidate(exerciseResultsProvider(profile.id));
                    },
                  ),
                  if (i < levels.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: context.colors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ],
        ),
      ),
    );
  }

  /// Regroupe les exercices par difficulté réelle, dans l'ordre pédagogique, et calcule la
  /// progression de l'élève. Public pour les tests.
  static List<PathLevel> buildLevels(List<Exercise> exercises, Map<String, bool?> results) {
    final byKey = <String, List<Exercise>>{};
    for (final e in exercises) {
      byKey.putIfAbsent(_normalize(e.difficulty), () => []).add(e);
    }
    final keys = byKey.keys.toList()
      ..sort((a, b) => _rank(a).compareTo(_rank(b)));

    final levels = <PathLevel>[];
    var previousUnlocksNext = true;
    for (final key in keys) {
      final items = byKey[key]!;
      var succeeded = 0, failed = 0;
      for (final e in items) {
        if (!results.containsKey(e.id)) continue;
        // `null` = format auto-évalué (rédaction…) : l'élève l'a fait, on le compte comme fait.
        if (results[e.id] == false) {
          failed++;
        } else {
          succeeded++;
        }
      }
      final ratio = items.isEmpty ? 0.0 : succeeded / items.length;
      final ordered = [...items]
        ..sort((a, b) => _order(results, a).compareTo(_order(results, b)));
      levels.add(PathLevel(
        label: _label(key),
        description: _description(key),
        total: items.length,
        succeeded: succeeded,
        failed: failed,
        unlocked: previousUnlocksNext,
        mastered: ratio >= masteryRatio,
        orderedExercises: ordered,
        neededToUnlockNext: (items.length * unlockRatio).ceil(),
      ));
      previousUnlocksNext = previousUnlocksNext && ratio >= unlockRatio;
    }
    return levels;
  }

  /// Jamais tentés d'abord, puis ratés, puis réussis.
  static int _order(Map<String, bool?> results, Exercise e) {
    if (!results.containsKey(e.id)) return 0;
    return results[e.id] == false ? 1 : 2;
  }

  static String _normalize(String raw) {
    const accents = {'é': 'e', 'è': 'e', 'ê': 'e', 'à': 'a', 'î': 'i', 'ô': 'o', 'û': 'u'};
    var s = raw.trim().toLowerCase();
    accents.forEach((k, v) => s = s.replaceAll(k, v));
    return s.isEmpty ? 'facile' : s;
  }

  static int _rank(String key) {
    const order = ['facile', 'intermediaire', 'moyen', 'difficile', 'approfondissement', 'bac', 'examen'];
    final i = order.indexOf(key);
    return i == -1 ? order.length : i;
  }

  static String _label(String key) => switch (key) {
        'facile' => 'Les bases',
        'intermediaire' || 'moyen' => 'Application',
        'difficile' => 'Raisonnement',
        'approfondissement' => 'Approfondissement',
        'bac' || 'examen' => 'Type examen',
        _ => key[0].toUpperCase() + key.substring(1),
      };

  static String _description(String key) => switch (key) {
        'facile' => 'Vérifier que le cours est compris.',
        'intermediaire' || 'moyen' => 'Utiliser le cours dans des exercices classiques.',
        'difficile' => 'Enchaîner plusieurs idées et justifier.',
        'approfondissement' => 'Questions plus poussées, proches des sujets d\'examen.',
        'bac' || 'examen' => 'Conditions d\'examen.',
        _ => 'Exercices de ce niveau.',
      };
}

class PathLevel {
  final String label;
  final String description;
  final int total;
  final int succeeded;
  final int failed;
  final bool unlocked;
  final bool mastered;
  final List<Exercise> orderedExercises;
  final int neededToUnlockNext;

  const PathLevel({
    required this.label,
    required this.description,
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.unlocked,
    required this.mastered,
    required this.orderedExercises,
    required this.neededToUnlockNext,
  });

  int get remaining => total - succeeded - failed;
}

class _LevelCard extends StatelessWidget {
  final PathLevel level;
  final int number;
  final bool isCurrent;
  final String? previousLabel;
  final VoidCallback onOpen;

  const _LevelCard({
    required this.level,
    required this.number,
    required this.isCurrent,
    required this.previousLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = level.mastered
        ? colors.accentEmerald
        : (level.unlocked ? colors.accentPrimary : colors.textMuted);
    final progress = level.total == 0 ? 0.0 : level.succeeded / level.total;

    final status = level.mastered
        ? 'Maîtrisé'
        : !level.unlocked
            ? 'Réussis d\'abord 60 % de « $previousLabel »'
            : level.succeeded + level.failed == 0
                ? 'Pas encore commencé'
                : '${level.succeeded}/${level.total} réussis'
                    '${level.failed > 0 ? ' · ${level.failed} à revoir' : ''}';

    return Opacity(
      opacity: level.unlocked ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: level.unlocked
            ? onOpen
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Niveau verrouillé : $status.')),
                ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent ? accent : colors.border,
              width: isCurrent ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: level.mastered
                    ? Icon(Icons.check_rounded, color: accent, size: 22)
                    : level.unlocked
                        ? Text(
                            '$number',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: accent,
                              fontSize: 16,
                            ),
                          )
                        : Icon(Icons.lock_outline_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${level.description} ${level.total} exercice${level.total > 1 ? 's' : ''}.',
                      style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: colors.surface,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: level.unlocked ? accent : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (level.unlocked)
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
