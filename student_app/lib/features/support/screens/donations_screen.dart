import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';

/// §12 du cahier des charges. Le catalogue des causes est réel (charity_campaigns, lecture
/// publique). Les dons eux-mêmes restent bloqués : la table `donations` n'a aucune policy
/// d'insertion cliente — un don ne peut être enregistré que via un agrégateur Mobile Money réel
/// (Campay/NotchPay/Monetbil), qui n'est pas encore connecté. On l'annonce honnêtement au clic
/// plutôt que de simuler un don réussi.
class DonationsScreen extends ConsumerWidget {
  const DonationsScreen({super.key});

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: StudentTheme.accentAmber,
        content: Text('Les dons Mobile Money ne sont pas encore disponibles : agrégateur de paiement en attente de configuration.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(charityCampaignsProvider);

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Soutien & Dons', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
      ),
      body: StudentPageContent(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Support the app directly
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: StudentTheme.purpleGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: StudentTheme.accentPurple.withOpacity(0.3), blurRadius: 16)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text('Soutenir l\'Application', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Un don libre, à tout moment, pour aider à maintenir la plateforme gratuite pour le plus grand nombre.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showUnavailable(context),
                  child: const Text('Faire un don libre', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('Soutenir une Œuvre Caritative', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 14),

          campaignsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (err, _) => Text('Erreur : $err', style: const TextStyle(color: Colors.red)),
            data: (campaigns) {
              if (campaigns.isEmpty) {
                return Text('Aucune campagne active pour le moment.', style: GoogleFonts.inter(color: StudentTheme.textSecondary));
              }
              return Column(
                children: campaigns.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: StudentTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: StudentTheme.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(c.description, style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: c.progressRatio.toDouble(),
                            minHeight: 8,
                            backgroundColor: StudentTheme.surfaceDark,
                            valueColor: const AlwaysStoppedAnimation(StudentTheme.accentEmerald),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${c.collectedAmount.toStringAsFixed(0)} / ${c.targetAmount.toStringAsFixed(0)} FCFA',
                                style: GoogleFonts.firaCode(fontSize: 11, color: StudentTheme.textMuted)),
                            TextButton(onPressed: () => _showUnavailable(context), child: const Text('Faire un don')),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      )),
    );
  }
}
