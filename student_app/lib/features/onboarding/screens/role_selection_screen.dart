import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/providers/app_root_providers.dart';
import '../../parent_portal/screens/parent_entry_screen.dart';

/// §17 du cahier des charges : l'Espace Parent est un PROFIL À PART ENTIÈRE, pas une page atteinte
/// depuis l'intérieur de l'app élève — ce choix est donc le tout premier écran de l'application,
/// avant même de savoir si un compte élève est déjà connu sur cet appareil. Un parent ne voit jamais
/// l'interface élève, et réciproquement (voir AppRootGate dans main.dart, qui vérifie une session
/// parent déjà active AVANT même d'afficher cet écran).
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.colors.accentPrimary, context.colors.accentIndigo],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'E-Learning National',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Qui utilise l\'application ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 36),
                  _RoleCard(
                    icon: Icons.school_outlined,
                    title: 'Je suis élève',
                    subtitle: 'Cours, exercices, Tuteur Numérique, examens...',
                    accent: context.colors.accentPrimary,
                    onTap: () => ref.read(hasChosenStudentRoleProvider.notifier).state = true,
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.family_restroom_rounded,
                    title: 'Je suis parent',
                    subtitle: 'Suivre la scolarité de mon enfant, gérer son abonnement',
                    accent: context.colors.accentAmber,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ParentEntryScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}
