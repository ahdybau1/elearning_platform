import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';

/// Dialogue « Modifier mes informations » de l'écran profil — extrait de `StudentProfileScreen`
/// (`_showEditProfileDialog`, découpage du fichier monolithique). `StatefulBuilder` conservé tel
/// quel (pas de conversion en widget à état propre) : le fichier d'origine ne libère jamais ses
/// contrôleurs (dette préexistante documentée, non corrigée ici pour ne pas changer le cycle de
/// vie dans ce refactor purement structurel).
class EditProfileDialog {
  const EditProfileDialog._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    StudentAccount account,
  ) {
    final firstNameCtrl = TextEditingController(text: account.firstName);
    final lastNameCtrl = TextEditingController(text: account.lastName);
    final schoolCtrl = TextEditingController(text: account.schoolName ?? '');
    DateTime? birthDate = account.birthDate;
    bool isSubmitting = false;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Modifier mes informations',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Prénom *',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nom *',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: schoolCtrl,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Établissement scolaire (optionnel)',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    birthDate != null
                        ? 'Date de naissance : ${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}'
                        : 'Date de naissance (optionnelle)',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.calendar_today_rounded,
                    color: context.colors.accentPrimary,
                    size: 18,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: birthDate ?? DateTime(2008),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => birthDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (firstNameCtrl.text.trim().isEmpty ||
                          lastNameCtrl.text.trim().isEmpty) {
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await ref
                          .read(studentAuthProvider.notifier)
                          .updateProfileInfo(
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            schoolName: schoolCtrl.text,
                            birthDate: birthDate,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted && error != null) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Modification du profil impossible.'),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
