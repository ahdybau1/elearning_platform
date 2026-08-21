import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/models/student_models.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../subscription/screens/paywall_modal.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final profile = authState.activeProfile;
    // Le champ pays direct sur le profil n'existe plus dans le vrai schéma (voir
    // docs/cahier_des_charges.md §36) — filtrage par pays retiré en attendant la refonte de la
    // couche de contenu (fetchSubjects interroge une colonne qui n'existe pas réellement, voir
    // student_supabase_service.dart).
    final subjectsAsync = ref.watch(studentSubjectsProvider(null));

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // Header App Bar with Profile Switcher
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 80,
            backgroundColor: StudentTheme.surfaceDark.withOpacity(0.9),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: StudentTheme.primaryGradient,
                        ),
                        child: Center(
                          child: Text(
                            profile?.name.isNotEmpty == true ? profile!.name[0].toUpperCase() : 'E',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile?.name ?? 'Élève',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            profile?.className ?? 'Classe',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: StudentTheme.accentPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Switch Profile Button
                      IconButton(
                        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                        tooltip: 'Changer de profil',
                        onPressed: () => Navigator.pushReplacementNamed(context, '/profiles'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Dashboard Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subscription Status / Upgrade Banner
                  if (profile?.hasActiveSubscription != true)
                    _buildSubscriptionBanner(context, ref)
                  else
                    _buildActivePassCard(profile!),

                  const SizedBox(height: 24),

                  // Temporal Unlocking & Trimester Tracker (Invisible unlocking concept)
                  _buildTrimesterStatusCard(),

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
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Programme Officiel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: StudentTheme.accentPrimary,
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
                          return _buildSubjectCard(context, subject);
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
          ),
        ],
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
            color: StudentTheme.accentPurple.withOpacity(0.3),
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
                    color: Colors.white,
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
              backgroundColor: Colors.white,
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

  Widget _buildActivePassCard(StudentProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudentTheme.accentEmerald.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StudentTheme.accentEmerald.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_rounded, color: StudentTheme.accentEmerald, size: 22),
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
                  style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimesterStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: StudentTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudentTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: StudentTheme.accentPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Trimestre 1 (En Cours)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: StudentTheme.accentEmerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DÉBLOQUÉ',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: StudentTheme.accentEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.65,
              backgroundColor: StudentTheme.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(StudentTheme.accentPrimary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Déblocage automatique du Trimestre 2 le 1er Décembre (invisible & fluide).',
            style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chapters',
          arguments: {'subjectId': subject.id, 'subjectName': subject.name},
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StudentTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: StudentTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.book_rounded, color: StudentTheme.accentPrimary, size: 20),
                ),
                Text(
                  '${(subject.progressPercent * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: StudentTheme.accentPrimary,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${subject.chaptersCount} chapitres',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: StudentTheme.textSecondary,
                  ),
                ),
              ],
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
        color: StudentTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudentTheme.accentCyan.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudentTheme.accentCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: StudentTheme.accentCyan, size: 24),
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
                  style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: StudentTheme.accentCyan),
            onPressed: () => Navigator.pushNamed(context, '/ai-tutor'),
          ),
        ],
      ),
    );
  }

}
