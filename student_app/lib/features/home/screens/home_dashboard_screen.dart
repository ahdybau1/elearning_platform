import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/theme/subject_visuals.dart';
import '../../../core/models/student_models.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../../subscription/screens/paywall_modal.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final profile = authState.activeProfile;
    // Matières réellement liées à la classe du profil actif (subject_class_links), jamais par pays
    // — voir le commentaire de fetchSubjects dans student_supabase_service.dart pour le bug de
    // cloisonnement que ce filtrage corrige. Chaîne vide tolérée pendant le bref instant où le
    // profil n'est pas encore chargé : fetchSubjects la traite comme un UUID invalide et renvoie []
    // sans erreur.
    final subjectsAsync = ref.watch(studentSubjectsProvider(profile?.classNodeId ?? ''));

    return StudentPageContent(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentScreenHeader(
              title: 'Tableau de Bord',
              subtitle: 'Bienvenue, ${profile?.name ?? 'Élève'} — ${profile?.className ?? ''}',
            ),
            const SizedBox(height: 24),
                  // Anniversaire (fonctionnalité hors CDC, approuvée explicitement par l'utilisateur)
                  if (authState.account?.isBirthdayToday == true) ...[
                    _buildBirthdayBanner(authState.account!.firstName),
                    const SizedBox(height: 24),
                  ],
                  // Subscription Status / Upgrade Banner
                  if (profile?.hasActiveSubscription != true)
                    _buildSubscriptionBanner(context, ref)
                  else
                    _buildActivePassCard(context, profile!),

                  const SizedBox(height: 24),

                  // §2.7 : compte à rebours vers l'examen officiel du profil actif — n'apparaît
                  // que si la classe compose réellement un examen national (§4).
                  if (profile != null) _buildExamCountdownBanner(ref, profile.classNodeId),

                  // Temporal Unlocking & Trimester Tracker (§2.7/§3.3 — dates réelles, plus de
                  // "Trimestre 1" ni de 65% codés en dur)
                  if (profile != null) _buildTrimesterStatusCard(context, ref, profile.classNodeId),

                  const SizedBox(height: 28),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vos Matières au Programme',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Programme Officiel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.colors.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Subjects Grid
                  subjectsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
                    data: (subjects) {
                      if (subjects.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.colors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.menu_book_outlined, color: context.colors.textMuted, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Aucune matière programmée pour ${profile?.className ?? 'votre classe'} pour le moment.',
                                  style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: subjects.length,
                        itemBuilder: (context, index) {
                          final subject = subjects[index];
                          return _buildSubjectCard(context, subject, profile?.classNodeId ?? '');
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // WhatsApp Official Community Card (Section 15 du CDC)
                  _buildWhatsAppCard(context),

                  const SizedBox(height: 24),

                  // AI Tutor Spotlight Card (Section 8 du CDC)
                  _buildAiTutorSpotlight(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: StudentTheme.purpleGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.accentPurple.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Débloquez Tout le Programme',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Accès illimité aux cours, corrigés d\'examens & IA Tuteur.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.textPrimary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => PaywallModal.show(context),
            child: Text(
              'Voir Offres',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayBanner(String firstName) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF59E0B)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Text('🎂', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Joyeux anniversaire, $firstName ! 🎉',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Toute l\'équipe d\'E-Learning National vous souhaite une excellente journée.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePassCard(BuildContext context, StudentProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.accentEmerald.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.accentEmerald.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.verified_rounded, color: context.colors.accentEmerald, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abonnement Actif : Pass ${profile.subscriptionTier.toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Accès complet aux fiches de cours, LaTeX & annales',
                  style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimesterStatusCard(BuildContext context, WidgetRef ref, String classNodeId) {
    final termAsync = ref.watch(currentTermInfoProvider(classNodeId));

    return termAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (err, _) => const SizedBox.shrink(),
      data: (term) {
        if (term == null) {
          // Aucun trimestre configuré par l'admin pour ce pays — état honnête, pas de bandeau
          // inventé plutôt qu'une fausse progression.
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: context.colors.accentPrimary),
                        const SizedBox(width: 8),
                        Text(
                          term.isBetweenTerms ? '${term.termName} (Terminé)' : '${term.termName} (En Cours)',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (term.schoolYearName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.accentEmerald.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ANNÉE ${term.schoolYearName}',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.accentEmerald),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: term.progressRatio,
                    backgroundColor: context.colors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(context.colors.accentPrimary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le contenu déjà couvert reste toujours accessible ; le trimestre suivant se débloque automatiquement à sa date.',
                  style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamCountdownBanner(WidgetRef ref, String classNodeId) {
    final examAsync = ref.watch(officialExamForClassProvider(classNodeId));

    return examAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => const SizedBox.shrink(),
      data: (exam) {
        if (exam == null || exam.examDate == null) return const SizedBox.shrink();
        final daysLeft = exam.examDate!.difference(DateTime.now()).inDays;
        if (daysLeft < 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    daysLeft == 0
                        ? "C'est aujourd'hui ! Bonne chance pour le ${exam.name} 🍀"
                        : 'Plus que $daysLeft jour${daysLeft > 1 ? 's' : ''} avant le ${exam.name} !',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject, String classNodeId) {
    final visual = SubjectVisuals.forSubject(code: subject.code, name: subject.name);
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chapters',
          arguments: {
            'subjectId': subject.id,
            'subjectName': subject.name,
            'subjectCode': subject.code,
            'classNodeId': classNodeId,
          },
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: visual.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: visual.gradient.last.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -14,
              child: SubjectMotif(icon: visual.icon, size: 92),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(visual.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subject.chaptersCount > 0 ? '${subject.chaptersCount} chapitres' : 'Bientôt disponible',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2F20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B6E47)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Groupe WhatsApp Officiel de la Classe',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Entraide, planning des devoirs et annonces du délégué.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8AE8B6)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ouverture du lien WhatsApp officiel...')),
              );
            },
            child: const Text('Rejoindre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTutorSpotlight(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.accentCyan.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.accentCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: context.colors.accentCyan, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besoin d\'aide sur un exercice ?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'L\'Assistant IA vous guide pas-à-pas sans donner la solution directement.',
                  style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: context.colors.accentCyan),
            onPressed: () => Navigator.pushNamed(context, '/ai-tutor'),
          ),
        ],
      ),
    );
  }

}
