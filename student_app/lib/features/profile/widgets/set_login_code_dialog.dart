import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/theme/student_theme.dart';

/// Dialogue « Définir / Changer mon code personnel » — extrait de `StudentProfileScreen`
/// (`_showSetLoginCodeDialog`, découpage du fichier monolithique). `StatefulBuilder` conservé :
/// `errorMessage!` repose sur la promotion d'une variable locale de closure, qui ne fonctionnerait
/// pas avec un champ d'instance dans un vrai `State`.
class SetLoginCodeDialog {
  const SetLoginCodeDialog._();

  static Future<void> show(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(
            'Définir mon code personnel',
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ce code vous appartient exclusivement — ne le partagez jamais.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: codeCtrl,
                obscureText: true,
                maxLength: 40,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nouveau code (4 à 40 caractères)',
                  labelStyle: TextStyle(color: context.colors.textSecondary),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                maxLength: 40,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirmer le code',
                  labelStyle: TextStyle(color: context.colors.textSecondary),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  errorMessage!,
                  style: TextStyle(
                    color: context.colors.accentRose,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
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
                backgroundColor: context.colors.accentIndigo,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim();
                      if (code.length < 4 || code.length > 40) {
                        setDialogState(
                          () => errorMessage =
                              'Le code doit comporter entre 4 et 40 caractères.',
                        );
                        return;
                      }
                      if (code != confirmCtrl.text.trim()) {
                        setDialogState(
                          () => errorMessage =
                              'Les deux codes ne correspondent pas.',
                        );
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorMessage = null;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await ref
                          .read(studentAuthProvider.notifier)
                          .setLoginCode(code);
                      if (error != null) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorMessage = error;
                        });
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Code personnel enregistré.'),
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
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.white,
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
