import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// CorrectionAgent (AIA-AGT-005, IA-009) — audit du 2026-09-06 : l'agent tournait déjà côté Gateway
/// Python (jamais déployée), donc réellement injoignable ; porté en Edge Function `ai-correction` le
/// même jour. Cet écran est le point d'entrée qui lui donnait un vrai rôle : sans lui, ses champs
/// ai_score/ai_feedback/needs_human_review n'étaient lus nulle part.
class ExerciseCorrectionsScreen extends ConsumerStatefulWidget {
  const ExerciseCorrectionsScreen({super.key});

  @override
  ConsumerState<ExerciseCorrectionsScreen> createState() => _ExerciseCorrectionsScreenState();
}

class _ExerciseCorrectionsScreenState extends ConsumerState<ExerciseCorrectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _correcting = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _correctWithAi(ExerciseAttemptForReview attempt) async {
    setState(() => _correcting.add(attempt.id));
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.correctAttemptWithAi(attempt.id);
      ref.invalidate(attemptsPendingCorrectionProvider);
      ref.invalidate(attemptsNeedingHumanReviewProvider);
      messenger.showSnackBar(
        const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Correction IA effectuée.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Échec : $e')));
    } finally {
      if (mounted) setState(() => _correcting.remove(attempt.id));
    }
  }

  Future<void> _review(ExerciseAttemptForReview attempt, bool officialCorrect) async {
    final admin = ref.read(authProvider).valueOrNull;
    if (admin == null) return;
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.reviewAttempt(attemptId: attempt.id, officialCorrect: officialCorrect, reviewerAdminId: admin.id);
      ref.invalidate(attemptsNeedingHumanReviewProvider);
      messenger.showSnackBar(
        const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Validation enregistrée.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Échec : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Corrections IA (AIA-AGT-005)',
              style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Réponses rédigées (réponse courte / rédaction) — le QCM a déjà une correction automatique fiable.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppTheme.accentCyan,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: const [
              Tab(text: 'À corriger'),
              Tab(text: 'À valider (revue humaine demandée)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PendingCorrectionList(correcting: _correcting, onCorrect: _correctWithAi),
                _NeedsReviewList(onReview: _review),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCorrectionList extends ConsumerWidget {
  const _PendingCorrectionList({required this.correcting, required this.onCorrect});
  final Set<String> correcting;
  final Future<void> Function(ExerciseAttemptForReview) onCorrect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(attemptsPendingCorrectionProvider);
    return attemptsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: AppTheme.accentRose))),
      data: (attempts) {
        if (attempts.isEmpty) {
          return Center(
            child: Text('Aucune tentative en attente de correction.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          );
        }
        return ListView.builder(
          itemCount: attempts.length,
          itemBuilder: (context, i) {
            final a = attempts[i];
            final busy = correcting.contains(a.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.exerciseTitle ?? 'Exercice',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(a.statement, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  Text('Réponse de l\'élève : ${a.submittedText}', maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : () => onCorrect(a),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                      icon: busy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(busy ? 'Correction en cours…' : 'Corriger avec l\'IA'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NeedsReviewList extends ConsumerWidget {
  const _NeedsReviewList({required this.onReview});
  final Future<void> Function(ExerciseAttemptForReview, bool) onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(attemptsNeedingHumanReviewProvider);
    return attemptsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: AppTheme.accentRose))),
      data: (attempts) {
        if (attempts.isEmpty) {
          return Center(
            child: Text('Aucune correction ne nécessite de revue humaine.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          );
        }
        return ListView.builder(
          itemCount: attempts.length,
          itemBuilder: (context, i) {
            final a = attempts[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.exerciseTitle ?? 'Exercice',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      if (a.aiScore != null)
                        Text('Score IA : ${(a.aiScore! * 100).round()}%',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentCyan)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Réponse de l\'élève : ${a.submittedText}', maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                  if (a.aiFeedback != null) ...[
                    const SizedBox(height: 8),
                    Text('Feedback IA : ${a.aiFeedback}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                  if (a.aiMisconceptions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Erreurs identifiées : ${a.aiMisconceptions.join(", ")}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentAmber)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () => onReview(a, true),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentEmerald),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Valider correct'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onReview(a, false),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRose),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Valider incorrect'),
                    ),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
