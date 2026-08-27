import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §14 du cahier des charges : concours blancs & olympiades. `events`/`event_results` en base ne
/// portent aucun lien vers un contenu d'épreuve (pas de question/exercice associé) — la correction se
/// fait hors-ligne. Cet écran informe et affiche les résultats déjà saisis par un admin ; il ne fait
/// jamais passer l'épreuve dans l'app (décision explicite, l'ancien "Participer" lançait un faux
/// chronomètre qui ne menait nulle part).
class MockExamArenaScreen extends ConsumerWidget {
  const MockExamArenaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final profile = authState.activeProfile;
    final eventsAsync = profile == null
        ? const AsyncValue<List<MockEvent>>.data([])
        : ref.watch(classEventsProvider(profile.classNodeId));

    return StudentPageContent(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StudentScreenHeader(title: 'Examens Blancs & Olympiades'),
            const SizedBox(height: 6),
            Text(
              'Épreuves nationales de votre classe (${profile?.className ?? ''}) — la correction se fait hors-ligne, les résultats et le classement apparaissent ici une fois publiés.',
              style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 24),
            eventsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text(
                'Erreur : $err',
                style: TextStyle(color: context.colors.accentRose),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return _EmptyState(className: profile?.className ?? 'votre classe');
                }
                return Column(
                  children: events
                      .map((e) => _EventCard(event: e, profileId: profile!.id))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String className;
  const _EmptyState({required this.className});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, color: context.colors.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            'Aucune épreuve programmée pour $className pour le moment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final MockEvent event;
  final String profileId;
  const _EventCard({required this.event, required this.profileId});

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = event.hasEnded
        ? ref.watch(myEventResultProvider(MyEventResultQuery(eventId: event.id, profileId: profileId)))
        : null;
    final accent = event.isOlympiad ? context.colors.accentAmber : context.colors.accentIndigo;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.isOlympiad ? 'OLYMPIADE' : 'CONCOURS BLANC',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
              const Spacer(),
              Text(
                event.hasEnded
                    ? 'Terminé'
                    : (event.isOngoing ? 'En cours' : 'À venir'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: event.hasEnded ? context.colors.textMuted : context.colors.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDate(event.startDate)} → ${_formatDate(event.endDate)} · ${event.pricingMode == 'inclus' ? 'Inclus dans votre abonnement' : '${event.price.toStringAsFixed(0)} FCFA'}',
            style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (event.hasEnded && resultAsync != null)
            resultAsync.when(
              loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const SizedBox.shrink(),
              data: (result) {
                if (result == null) {
                  return Text(
                    'Résultat pas encore publié pour vous.',
                    style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '${result.score.toStringAsFixed(1)}/20',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.colors.accentEmerald,
                            ),
                          ),
                          if (result.rank != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              'Rang #${result.rank}',
                              style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showLeaderboard(context, ref),
                      child: Text('Classement', style: TextStyle(color: context.colors.accentPrimary)),
                    ),
                    TextButton(
                      onPressed: () => _showDisputeDialog(context, ref, result),
                      child: Text('Contester', style: TextStyle(color: context.colors.accentRose)),
                    ),
                  ],
                );
              },
            )
          else
            OutlinedButton(
              onPressed: () => _showDetails(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.border),
              ),
              child: const Text('Détails de l\'épreuve'),
            ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(event.title, style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Type : ${event.isOlympiad ? 'Olympiade' : 'Concours blanc'}\n'
          'Période : ${_formatDate(event.startDate)} → ${_formatDate(event.endDate)}\n'
          'Tarif : ${event.pricingMode == 'inclus' ? 'Inclus dans votre abonnement' : '${event.price.toStringAsFixed(0)} FCFA'}\n\n'
          'Cette épreuve se déroule hors de l\'application (copie corrigée par un examinateur). '
          'Vos résultats et votre classement apparaîtront ici dès leur publication.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: context.colors.accentPrimary)),
          ),
        ],
      ),
    );
  }

  void _showLeaderboard(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Classement — ${event.title}', style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
        content: SizedBox(
          width: 360,
          child: Consumer(
            builder: (context, ref, _) {
              final leaderboardAsync = ref.watch(eventLeaderboardProvider(event.id));
              return leaderboardAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Erreur : $err', style: TextStyle(color: context.colors.accentRose)),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Text(
                      'Classement pas encore publié.',
                      style: TextStyle(color: context.colors.textSecondary),
                    );
                  }
                  return SizedBox(
                    height: 320,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        final isTop3 = (entry.rank ?? 99) <= 3;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isTop3
                                  ? context.colors.accentAmber.withValues(alpha: 0.4)
                                  : context.colors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                entry.rank != null ? '#${entry.rank}' : '—',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: isTop3 ? context.colors.accentAmber : context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${entry.firstName} (${entry.className})',
                                  style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${entry.score.toStringAsFixed(1)}/20',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.accentEmerald,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: context.colors.accentPrimary)),
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog(BuildContext context, WidgetRef ref, MyEventResult result) {
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Row(
            children: [
              Icon(Icons.gavel_rounded, color: context.colors.accentRose),
              const SizedBox(width: 10),
              Text('Demande de 2e Correcteur', style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre copie sera transmise à un examinateur indépendant, sans communication de la 1ère note, pour garantir l\'équité (§11 du cahier des charges).',
                style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Précisez l\'exercice ou la question contestée...',
                  hintStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: context.colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentRose),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (reasonCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      final error = await ref.read(studentSupabaseServiceProvider).submitGradeDispute(
                            eventResultId: result.id,
                            reason: reasonCtrl.text.trim(),
                            originalScore: result.score,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error == null
                                  ? 'Demande de réclamation enregistrée.'
                                  : 'Erreur : $error',
                            ),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Soumettre', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
