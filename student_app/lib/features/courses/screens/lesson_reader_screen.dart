import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/services/forensic_watermark_service.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../subscription/screens/paywall_modal.dart';

class LessonReaderScreen extends ConsumerWidget {
  final String chapterId;
  final String chapterTitle;

  const LessonReaderScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final profile = authState.activeProfile;
    final lessonsAsync = ref.watch(studentLessonsProvider(chapterId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          chapterTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.colors.textPrimary, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download_for_offline_rounded, color: context.colors.accentEmerald),
            tooltip: 'Télécharger pour le mode Hors-Ligne (Data-Saver)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: context.colors.accentEmerald,
                  content: Text('Leçon enregistrée en mode Hors-Ligne avec Forensic Watermark.'),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.quiz_rounded, color: context.colors.accentPrimary),
            tooltip: 'Passer aux exercices',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/exercises',
                arguments: {'chapterId': chapterId, 'chapterTitle': chapterTitle},
              );
            },
          ),
        ],
      ),
      body: StudentPageContent(child: lessonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
        data: (lessons) {
          if (lessons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 46, color: context.colors.textMuted),
                    const SizedBox(height: 16),
                    Text('Aucune leçon publiée pour ce chapitre',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Revenez bientôt : l\'enseignant est en train de préparer ce cours.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          final lesson = lessons.first;
          final isLocked = !lesson.isFree && (profile?.hasActiveSubscription != true);

          final readerContent = SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lesson Title & Reading Time Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lesson.title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: context.colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${lesson.readingTimeMinutes} min',
                            style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Introduction / Body Text
                Text(
                  lesson.contentJson['body'] ?? 'Contenu pédagogique officiel conforme au programme.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: context.colors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Bloc Théorème Majeur (Section 16.0)
                if (lesson.contentJson['theoreme'] != null)
                  _buildTheoremeCard(context, lesson.contentJson['theoreme']),

                const SizedBox(height: 20),

                // 2. Bloc Formules Clés (LaTeX)
                if (lesson.contentJson['formule'] != null)
                  _buildFormulaCard(context, lesson.contentJson['formule']),

                const SizedBox(height: 20),

                // 3. Bloc Piège & Erreur Fréquente aux Examens
                if (lesson.contentJson['piege'] != null)
                  _buildTrapCard(context, lesson.contentJson['piege']),

                const SizedBox(height: 20),

                // 4. Bloc Méthode de Résolution
                if (lesson.contentJson['methode'] != null)
                  _buildMethodCard(context, lesson.contentJson['methode']),

                const SizedBox(height: 32),

                // Bottom Action: Launch Quiz Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Validez vos connaissances',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Testez votre compréhension avec le quiz interactif de ce chapitre.',
                        style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.accentPrimary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/exercises',
                            arguments: {'chapterId': chapterId, 'chapterTitle': chapterTitle},
                          );
                        },
                        icon: const Icon(Icons.quiz_rounded),
                        label: const Text('Démarrer les Exercices', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          // If user does not have required subscription tier, apply Smart Paywall Blur overlay
          if (isLocked) {
            return Stack(
              children: [
                // Blurred reader content
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.darken),
                  child: readerContent,
                ),
                // Paywall Callout Modal
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.colors.accentPrimary.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.accentPrimary.withOpacity(0.2),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.colors.accentPrimary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.lock_rounded, color: context.colors.accentPrimary, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Contenu Premium Réservé',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cette leçon complète, ses formules détaillées et ses corrigés d\'examens nécessitent un Pass Mensuel ou Annuel.',
                              style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.accentPrimary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => PaywallModal.show(context),
                              child: const Text('Débloquer avec Mobile Money', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Protected with Forensic Watermark
          return profile != null
              ? ForensicWatermarkService.buildWatermarkedContainer(
                  profile: profile,
                  phoneNumber: authState.account?.phone ?? '+237 699 00 00 00',
                  child: readerContent,
                )
              : readerContent;
        },
      )),
    );
  }

  Widget _buildTheoremeCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF132338),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: context.colors.accentPrimary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: context.colors.accentPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Théorème Majeur & Définition',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.functions_rounded, color: context.colors.accentEmerald, size: 18),
              const SizedBox(width: 8),
              Text(
                'Formules & Propriétés Clés (LaTeX)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              style: GoogleFonts.firaCode(fontSize: 15, color: context.colors.textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrapCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C161E),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: context.colors.accentRose, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: context.colors.accentRose, size: 18),
              const SizedBox(width: 8),
              Text(
                'Piège Classique d\'Examen',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.accentRose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: context.colors.accentAmber, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: context.colors.accentAmber, size: 18),
              const SizedBox(width: 8),
              Text(
                'Méthode & Savoir-Faire',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.accentAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }
}
