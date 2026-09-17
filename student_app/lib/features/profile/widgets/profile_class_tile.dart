import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';

/// Tuile d'une classe suivie (« Mes Classes Suivies ») — extraite de `StudentProfileScreen`
/// (découpage du fichier monolithique, `docs/UI_REDESIGN_PLAN.md` Vague 3). Purement présentielle :
/// l'archivage reste piloté par l'écran parent via [onArchive].
class ProfileClassTile extends StatelessWidget {
  const ProfileClassTile({
    super.key,
    required this.profile,
    required this.isActive,
    required this.canArchive,
    required this.onArchive,
  });

  final StudentProfile profile;
  final bool isActive;
  final bool canArchive;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? context.colors.accentPrimary.withValues(alpha: 0.6)
              : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: context.colors.accentIndigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.school_outlined,
              color: context.colors.accentIndigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // `Flexible` : un nom de classe long + le badge « Actif » + l'icône
                    // d'archivage + le badge d'abonnement débordaient sur mobile (jamais
                    // détecté faute de test sur cet écran) — le nom s'ellipse maintenant au
                    // lieu de pousser le reste de la ligne hors de l'écran.
                    Flexible(
                      child: Text(
                        profile.className,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.accentPrimary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Actif',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: context.colors.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Année ${profile.schoolYear}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: profile.hasActiveSubscription
                  ? context.colors.accentEmerald.withValues(alpha: 0.15)
                  : context.colors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              profile.hasActiveSubscription
                  ? 'Pass ${profile.subscriptionTier.toUpperCase()}'
                  : 'Gratuit',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: profile.hasActiveSubscription
                    ? context.colors.accentEmerald
                    : context.colors.textSecondary,
              ),
            ),
          ),
          if (canArchive) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Archiver cette classe',
              icon: Icon(
                Icons.archive_outlined,
                size: 18,
                color: context.colors.textMuted,
              ),
              onPressed: onArchive,
            ),
          ],
        ],
      ),
    );
  }
}
