import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/student_theme.dart';

class PaywallModal extends ConsumerStatefulWidget {
  const PaywallModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PaywallModal(),
    );
  }

  @override
  ConsumerState<PaywallModal> createState() => _PaywallModalState();
}

class _PaywallModalState extends ConsumerState<PaywallModal> {
  int _selectedTierIndex = 1; // 0: Découverte, 1: Mensuel, 2: Annuel

  final List<Map<String, dynamic>> _tiers = [
    {
      'id': 'decouverte',
      'name': 'Pass Découverte',
      'duration': '7 Jours',
      'price': '1 000 FCFA',
      'days': 7,
      'features': [
        'Accès au 1er Trimestre',
        'Quiz interactifs',
        'Support IA basique',
      ],
    },
    {
      'id': 'mensuel',
      'name': 'Pass Mensuel (Recommandé)',
      'duration': '30 Jours',
      'price': '3 500 FCFA',
      'days': 30,
      'features': [
        'Tout le programme débloqué',
        'Annales & Corrigés d\'examens',
        'Mode Hors-Ligne Data-Saver',
      ],
    },
    {
      'id': 'annuel',
      'name': 'Pass Annuel (Excellence)',
      'duration': 'Année scolaire',
      'price': '25 000 FCFA',
      'days': 365,
      'features': [
        'Accès complet 365 jours',
        'Olympiades & Examens blancs',
        'Garantie 2e correcteur',
        'Remise de 40% sur la boutique',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedTier = _tiers[_selectedTierIndex];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Choisissez votre Formule d\'Excellence',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Comparez les formules. Le paiement sera activé après la connexion sécurisée d\'un opérateur Mobile Money.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Tiers Selector
            ...List.generate(_tiers.length, (index) {
              final tier = _tiers[index];
              final isSel = _selectedTierIndex == index;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSel ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel
                        ? context.colors.accentPrimary
                        : context.colors.border,
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    tier['name'],
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isSel
                          ? context.colors.accentPrimary
                          : context.colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    (tier['features'] as List).join(' • '),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    tier['price'],
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  onTap: () => setState(() => _selectedTierIndex = index),
                ),
              );
            }),

            const SizedBox(height: 16),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colors.accentAmber.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: context.colors.accentAmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aucun prélèvement ne sera effectué tant que le paiement n\'est pas connecté.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pay Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: null,
              child: Text(
                'Paiement bientôt disponible • ${selectedTier['price']}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
