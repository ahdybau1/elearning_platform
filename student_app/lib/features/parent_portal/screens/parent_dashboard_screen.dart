import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final profiles = authState.profiles;

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.family_restroom_rounded, color: StudentTheme.accentAmber),
            SizedBox(width: 10),
            Text('Espace Parent & Suivi Scolaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          'Compte Parent : ${authState.account?.email ?? 'famille.kamga@gmail.com'}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          'Mobile Money : ${authState.account?.phoneNumber ?? '+237 699 12 34 56'}',
                          style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: StudentTheme.textSecondary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Paramètres du compte parent.')),
                      );
                    },
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
                                  '${p.className} • ${p.schoolName ?? 'Établissement'}',
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
                            p.hasActiveSubscription ? 'Pass ${p.activeTier.toUpperCase()}' : 'Accès Gratuit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: p.hasActiveSubscription ? StudentTheme.accentEmerald : StudentTheme.accentRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: StudentTheme.borderDark),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Assiduité', '${p.streakDays} jours consécutifs', Icons.local_fire_department_rounded, Colors.orange),
                        _buildStatItem('Points XP', '${p.totalPoints} XP', Icons.stars_rounded, StudentTheme.accentAmber),
                        _buildStatItem('Moyenne Quiz', '16.5 / 20', Icons.analytics_rounded, StudentTheme.accentEmerald),
                      ],
                    ),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textMuted)),
      ],
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
}
