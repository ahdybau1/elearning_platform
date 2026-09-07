import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/published_exam_question.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/components/empty_state_view.dart';

/// D.9 : lecture des questions publiées, original conservé et corrigé sur demande.
class ExamQuestionsScreen extends ConsumerWidget {
  const ExamQuestionsScreen({super.key, required this.title, required this.documentUrl,
    this.examPaperId, this.establishmentPaperId})
    : assert((examPaperId == null) != (establishmentPaperId == null));
  final String title;
  final String documentUrl;
  final String? examPaperId;
  final String? establishmentPaperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final query = (profileId: profile?.id ?? '', examPaperId: examPaperId,
      establishmentPaperId: establishmentPaperId);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: profile == null ? const Center(child: Text('Sélectionnez un profil pour consulter ce sujet.'))
        : ref.watch(publishedExamQuestionsProvider(query)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Ce sujet est indisponible ou n’est pas inclus dans votre accès.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => ref.invalidate(publishedExamQuestionsProvider(query)),
                child: const Text('Réessayer')),
            ]))),
          data: (questions) => ExamQuestionsContent(
            key: ValueKey(query), questions: questions,
            onOpenOriginal: documentUrl.isEmpty ? null : () async {
              final uri = Uri.tryParse(documentUrl);
              final valid = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
              try {
                if (!valid || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  throw StateError('Document indisponible');
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impossible d’ouvrir le document original.')),
                  );
                }
              }
            },
          ),
        ),
    );
  }
}

class ExamQuestionsContent extends StatelessWidget {
  const ExamQuestionsContent({super.key, required this.questions, this.onOpenOriginal});
  final List<PublishedExamQuestion> questions;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Align(alignment: Alignment.topCenter, child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(
          'Le sujet, question par question',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.accentPrimary.withValues(alpha: 0.12),
              borderRadius: AppRadius.radiusFull,
            ),
            child: Text(
              '${questions.length} question(s) publiée(s)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accentPrimary,
              ),
            ),
          ),
          if (onOpenOriginal != null)
            OutlinedButton.icon(
              onPressed: onOpenOriginal,
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Document original (PDF)'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMedium),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          'Travaillez chaque question à votre rythme, puis consultez le corrigé lorsqu’il est disponible.',
          style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (questions.isEmpty)
          const EmptyStateView(
            icon: Icons.quiz_outlined,
            title: 'Aucune question publiée',
            description: 'Les questions et corrigés de ce sujet sont en cours de préparation.',
          )
        else
          for (final question in questions)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: AppRadius.radiusLarge,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Text(
                          'Question ${question.order}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InlineLatexText(
                    question.statement,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (question.answer?.trim().isNotEmpty ?? false)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.accentEmerald.withValues(alpha: 0.07),
                        borderRadius: AppRadius.radiusMedium,
                        border: Border.all(
                          color: colors.accentEmerald.withValues(alpha: 0.25),
                        ),
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: Icon(Icons.verified_rounded, color: colors.accentEmerald, size: 20),
                        title: Text(
                          'Voir le corrigé relu',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.accentEmerald,
                          ),
                        ),
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Proposition issue du traitement IA, relue et approuvée par l’équipe pédagogique.',
                            style: GoogleFonts.inter(fontSize: 11, color: colors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InlineLatexText(
                              question.answer!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.6,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Corrigé non encore disponible pour cette question.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
      ]),
    ));
  }
}
