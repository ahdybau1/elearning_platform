import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';

/// Données réelles (compte + profils déjà chargés par studentAuthProvider) — rien à simuler ici,
/// contrairement aux autres pages ajoutées dans cette même passe qui restent volontairement
/// factices en attendant leur propre passe de rigueur.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final account = authState.account;
    final activeProfile = authState.activeProfile;

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Mon Profil', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
      ),
      body: StudentPageContent(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: StudentTheme.cardDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: StudentTheme.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: StudentTheme.primaryGradient),
                    child: Center(
                      child: Text(
                        (account?.firstName.isNotEmpty == true) ? account!.firstName[0].toUpperCase() : 'É',
                        style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${account?.firstName ?? ''} ${account?.lastName ?? ''}'.trim(),
                          style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(account?.email ?? '', style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary)),
                        if (account?.phone?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(account!.phone!, style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modifier mes informations (bientôt disponible)',
                    icon: const Icon(Icons.edit_outlined, color: StudentTheme.textMuted),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La modification du profil arrive bientôt.')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Text('Mes Classes Suivies', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              'Modèle 1 profil = 1 classe = 1 abonnement (§2.3 du cahier des charges).',
              style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
            ),
            const SizedBox(height: 14),

            ...authState.profiles.map((p) => _buildProfileTile(p, isActive: p.id == activeProfile?.id)),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/onboarding'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter une classe'),
              style: OutlinedButton.styleFrom(
                foregroundColor: StudentTheme.accentPrimary,
                side: const BorderSide(color: StudentTheme.accentPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: StudentTheme.cardDark.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudentTheme.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.military_tech_outlined, color: StudentTheme.textMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Badges, séries de régularité & points',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Gamification (§14 du cahier des charges) — bientôt disponible.',
                            style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildProfileTile(StudentProfile p, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: StudentTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? StudentTheme.accentPrimary.withOpacity(0.6) : StudentTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: StudentTheme.accentIndigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_outlined, color: StudentTheme.accentIndigo, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.className, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: StudentTheme.accentPrimary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text('Actif', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: StudentTheme.accentPrimary)),
                      ),
                    ],
                  ],
                ),
                Text('Année ${p.schoolYear}', style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.hasActiveSubscription ? StudentTheme.accentEmerald.withOpacity(0.15) : StudentTheme.surfaceDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.hasActiveSubscription ? 'Pass ${p.subscriptionTier.toUpperCase()}' : 'Gratuit',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold,
                  color: p.hasActiveSubscription ? StudentTheme.accentEmerald : StudentTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
