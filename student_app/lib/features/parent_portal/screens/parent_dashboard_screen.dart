import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final profiles = authState.profiles;

    return StudentPageContent(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StudentScreenHeader(
              title: 'Espace Parent & Suivi Scolaire',
              subtitle: 'Suivi individuel, abonnement et communication avec l\'administration.',
            ),
            const SizedBox(height: 20),
            // Parent Account Info Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: StudentTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudentTheme.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StudentTheme.accentAmber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: StudentTheme.accentAmber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte : ${authState.account?.email ?? '...'}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          'Mobile Money : ${authState.account?.phone ?? 'Non renseigné'}',
                          style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: StudentTheme.textSecondary),
                    onPressed: () => _showSupportAndLegalSheet(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Suivi Individuel des Enfants',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 14),

            // Children Progress Cards
            ...profiles.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: StudentTheme.primaryGradient,
                              ),
                              child: Center(
                                child: Text(
                                  p.name[0].toUpperCase(),
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                ),
                                Text(
                                  'Année scolaire ${p.schoolYear}',
                                  style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.hasActiveSubscription
                                ? StudentTheme.accentEmerald.withOpacity(0.15)
                                : StudentTheme.accentRose.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.hasActiveSubscription ? 'Pass ${p.subscriptionTier.toUpperCase()}' : 'Accès Gratuit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: p.hasActiveSubscription ? StudentTheme.accentEmerald : StudentTheme.accentRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // La gamification (streak, points XP) et les moyennes de quiz n'ont pas encore
                    // de table réelle en base (voir docs/cahier_des_charges.md §14) — retiré plutôt
                    // que d'afficher des chiffres inventés en attendant ce chantier.
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Receipts / Payment History Section
            Text(
              'Historique & Reçus de Paiement',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StudentTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudentTheme.borderDark),
              ),
              child: Column(
                children: [
                  _buildPaymentHistoryRow('Pass Mensuel Junior (Terminale C)', '3 500 FCFA', '12 Août 2026', 'Orange Money'),
                  const Divider(color: StudentTheme.borderDark),
                  _buildPaymentHistoryRow('Formulaire Maths (Boutique)', '500 FCFA', '05 Août 2026', 'MTN MoMo'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryRow(String title, String amount, String date, String method) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('$date • $method', style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textMuted)),
            ],
          ),
          Text(amount, style: GoogleFonts.firaCode(fontSize: 13, fontWeight: FontWeight.bold, color: StudentTheme.accentEmerald)),
        ],
      ),
    );
  }

  void _showSupportAndLegalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: StudentTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final settingsAsync = ref.watch(appSettingsProvider);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: settingsAsync.when(
              data: (settings) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Support & Informations Légales',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  if (settings.supportEmail?.isNotEmpty == true)
                    _infoRow(Icons.email_outlined, 'Email', settings.supportEmail!),
                  if (settings.supportPhone?.isNotEmpty == true)
                    _infoRow(Icons.phone_outlined, 'Téléphone', settings.supportPhone!),
                  if (settings.supportWhatsappLink?.isNotEmpty == true)
                    _infoRow(Icons.chat_outlined, 'WhatsApp', settings.supportWhatsappLink!),
                  if (settings.termsUrl?.isNotEmpty == true)
                    _infoRow(Icons.description_outlined, 'CGU', settings.termsUrl!),
                  if (settings.privacyPolicyUrl?.isNotEmpty == true)
                    _infoRow(Icons.privacy_tip_outlined, 'Confidentialité', settings.privacyPolicyUrl!),
                  if (settings.legalNoticeUrl?.isNotEmpty == true)
                    _infoRow(Icons.gavel_outlined, 'Mentions légales', settings.legalNoticeUrl!),
                  if ((settings.supportEmail?.isEmpty ?? true) &&
                      (settings.supportPhone?.isEmpty ?? true) &&
                      (settings.supportWhatsappLink?.isEmpty ?? true) &&
                      (settings.termsUrl?.isEmpty ?? true) &&
                      (settings.privacyPolicyUrl?.isEmpty ?? true) &&
                      (settings.legalNoticeUrl?.isEmpty ?? true))
                    Text('Aucune information de support renseignée par l\'administration pour le moment.',
                        style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary)),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Text('Erreur: $err', style: GoogleFonts.inter(color: Colors.redAccent)),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: StudentTheme.accentAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textMuted)),
                SelectableText(value, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
