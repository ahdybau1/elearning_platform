import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';

/// Section « Classes archivées » de l'écran profil — extraite de `StudentProfileScreen`
/// (`_buildArchivedProfilesSection` + `_reactivate`, découpage du fichier monolithique).
class ArchivedClassesSection extends ConsumerStatefulWidget {
  const ArchivedClassesSection({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<ArchivedClassesSection> createState() =>
      _ArchivedClassesSectionState();
}

class _ArchivedClassesSectionState
    extends ConsumerState<ArchivedClassesSection> {
  Future<void> _reactivate(String profileId) async {
    final error = await ref
        .read(studentAuthProvider.notifier)
        .reactivateProfile(profileId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réactivation impossible pour le moment.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Classe réactivée.')));
      // Sans argument : invalide toute la famille de providers (comportement identique à
      // l'écran monolithique d'origine — restreindre à `accountId` serait un changement de
      // comportement, pas une simple extraction).
      ref.invalidate(archivedProfilesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivedAsync = ref.watch(archivedProfilesProvider(widget.accountId));

    return archivedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => const SizedBox.shrink(),
      data: (archived) {
        if (archived.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classes archivées',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Masqués mais conservés — réactivables à tout moment (§2.5 du cahier des charges).',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ...archived.map(
              (p) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.colors.card.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.className,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          Text(
                            'Année ${p.schoolYear}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _reactivate(p.id),
                      icon: Icon(
                        Icons.restore_rounded,
                        size: 16,
                        color: context.colors.accentPrimary,
                      ),
                      label: Text(
                        'Réactiver',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.colors.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
