import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';
import 'edit_profile_dialog.dart';
import 'profile_avatar_uploader.dart';

/// Carte d'identité (avatar + nom/email/téléphone/école/date de naissance + bouton d'édition) de
/// l'écran profil — extraite de `StudentProfileScreen` (découpage du fichier monolithique).
class ProfileIdentityCard extends ConsumerWidget {
  const ProfileIdentityCard({super.key, required this.account});

  final StudentAccount? account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Variable locale (pas `this.account` direct) : Dart ne promeut le type qu'après un `!`/null
    // check sur une variable locale, jamais sur un champ — sans cette ombre, les accès
    // `account.birthDate` après un premier `account!.birthDate` plus haut dans la même
    // interpolation seraient rejetés par l'analyseur.
    final account = this.account;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          ProfileAvatarUploader(account: account),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account?.firstName ?? ''} ${account?.lastName ?? ''}'
                      .trim(),
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
                if (account?.phone?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    account!.phone!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                if (account?.schoolName?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    '🏫 ${account!.schoolName}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                if (account?.birthDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '🎂 ${account!.birthDate!.day.toString().padLeft(2, '0')}/${account.birthDate!.month.toString().padLeft(2, '0')}/${account.birthDate!.year}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifier mes informations',
            icon: Icon(Icons.edit_outlined, color: context.colors.textMuted),
            onPressed: account == null
                ? null
                : () => EditProfileDialog.show(context, ref, account),
          ),
        ],
      ),
    );
  }
}
