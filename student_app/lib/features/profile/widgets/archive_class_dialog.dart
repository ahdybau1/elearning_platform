import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';

/// Confirmation d'archivage d'une classe suivie — extraite de `StudentProfileScreen`
/// (`_confirmArchive`, découpage du fichier monolithique). Ne fait que retourner le choix de
/// l'élève : l'appel réel à `archiveProfile` reste dans l'écran/section appelante.
class ArchiveClassDialog extends StatelessWidget {
  const ArchiveClassDialog({super.key, required this.profile});

  final StudentProfile profile;

  static Future<bool?> show(BuildContext context, StudentProfile profile) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ArchiveClassDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.card,
      title: Text(
        'Archiver cette classe ?',
        style: GoogleFonts.outfit(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        '${profile.name} (${profile.className}) sera masqué mais pourra être réactivé à tout moment. Aucune donnée n\'est supprimée (§2.5 du cahier des charges).',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: context.colors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Annuler',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Archiver',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
