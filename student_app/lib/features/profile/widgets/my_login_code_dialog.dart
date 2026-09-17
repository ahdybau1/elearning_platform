import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/theme/student_theme.dart';

/// Dialogue « Voir mon code personnel » — extrait de `StudentProfileScreen`
/// (`_showMyLoginCodeDialog`, découpage du fichier monolithique). Le code est récupéré AVANT
/// l'ouverture du dialogue (comportement d'origine conservé à l'identique) : rien ne s'affiche
/// pendant l'attente réseau, ajouter un état de chargement dans le dialogue serait un changement
/// de comportement, pas une simple extraction.
class MyLoginCodeDialog {
  const MyLoginCodeDialog._();

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final code = await ref
        .read(studentAuthProvider.notifier)
        .fetchMyLoginCode();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Mon code personnel',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: code == null
            ? Text(
                'Aucun code défini pour l\'instant.',
                style: TextStyle(color: context.colors.textSecondary),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  code,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.firaCode(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fermer',
              style: TextStyle(color: context.colors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
