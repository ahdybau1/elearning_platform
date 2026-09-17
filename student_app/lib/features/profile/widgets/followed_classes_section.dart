import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';
import 'archive_class_dialog.dart';
import 'profile_class_tile.dart';

/// Section « Mes Classes Suivies » de l'écran profil — extraite de `StudentProfileScreen`
/// (le rendu de la liste + `_confirmArchive`, découpage du fichier monolithique).
class FollowedClassesSection extends ConsumerStatefulWidget {
  const FollowedClassesSection({
    super.key,
    required this.profiles,
    required this.activeProfileId,
  });

  final List<StudentProfile> profiles;
  final String? activeProfileId;

  @override
  ConsumerState<FollowedClassesSection> createState() =>
      _FollowedClassesSectionState();
}

class _FollowedClassesSectionState
    extends ConsumerState<FollowedClassesSection> {
  Future<void> _confirmArchive(StudentProfile p) async {
    final confirmed = await ArchiveClassDialog.show(context, p);
    if (confirmed != true) return;
    if (!mounted) return;
    final error = await ref
        .read(studentAuthProvider.notifier)
        .archiveProfile(p.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivage impossible pour le moment.')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Classe archivée.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes Classes Suivies',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Chaque classe suivie a son propre suivi et son propre abonnement.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ...widget.profiles.map(
          (p) => ProfileClassTile(
            profile: p,
            isActive: p.id == widget.activeProfileId,
            canArchive: widget.profiles.length > 1,
            onArchive: () => _confirmArchive(p),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/onboarding'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ajouter une classe'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.accentPrimary,
            side: BorderSide(color: context.colors.accentPrimary),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
