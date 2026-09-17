import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/student_theme.dart';
import 'my_login_code_dialog.dart';
import 'set_login_code_dialog.dart';

/// Carte « Sécurité — Mon code » de l'écran profil — extraite de `StudentProfileScreen`
/// (`_buildLoginCodeCard`, découpage du fichier monolithique). §7.3/§7.4 du cahier des charges :
/// définit/consulte le code personnel utilisé pour le déverrouillage rapide (voir
/// device_accounts_service.dart et login_code_entry_screen.dart). Migration 48 : chiffrement
/// réversible (plus un hash à sens unique) précisément pour permettre cette consultation par le
/// propriétaire.
///
/// Restructuré (2026-08-30, retour utilisateur réel) : icône + texte + 2 boutons tenaient tous dans
/// une seule Row sans aucune protection — débordait forcément sur mobile. Icône+texte au-dessus,
/// boutons dans un Wrap en dessous (passent à la ligne au besoin plutôt que de déborder).
class LoginCodeCard extends ConsumerWidget {
  const LoginCodeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
            children: [
              Icon(
                Icons.pin_outlined,
                color: context.colors.accentIndigo,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sécurité — Mon code',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code personnel (lettres, chiffres, caractères) pour vous reconnecter rapidement sur cet appareil.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => MyLoginCodeDialog.show(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textSecondary,
                  side: BorderSide(color: context.colors.border),
                ),
                child: const Text('Voir'),
              ),
              OutlinedButton(
                onPressed: () => SetLoginCodeDialog.show(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.accentIndigo,
                  side: BorderSide(color: context.colors.accentIndigo),
                ),
                child: const Text('Définir / Changer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
