import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/student_theme.dart';
import 'parent_auth_provider.dart';

/// Point d'entrée unique vers l'Espace Parent (§17 du cahier des charges), utilisé depuis
/// `profile_switcher_screen.dart` et `main_navigation_screen.dart`. Remplace l'ancien PIN codé en
/// dur : si une session parent réelle est déjà active (restaurée automatiquement au démarrage,
/// voir `ParentAuthNotifier`), on navigue directement — « sans réauthentification constante » comme
/// l'exige le CDC. Sinon, un vrai formulaire email + mot de passe (compte créé par un administrateur,
/// voir la doc de `admin-create-parent-account`).
Future<void> openParentSpace(BuildContext context, WidgetRef ref) async {
  final parentState = ref.read(parentAuthProvider);
  if (parentState.isAuthenticated) {
    if (context.mounted) Navigator.pushNamed(context, '/parent-portal');
    return;
  }
  await _showParentLoginDialog(context, ref);
}

Future<void> _showParentLoginDialog(BuildContext context, WidgetRef ref) async {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: context.colors.accentAmber),
            const SizedBox(width: 10),
            Text('Espace Parent', style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connectez-vous avec le compte parent créé par l\'administration.',
                style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: context.colors.textSecondary),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email invalide' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  labelStyle: TextStyle(color: context.colors.textSecondary),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                onFieldSubmitted: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentAmber),
            onPressed: isSubmitting
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setDialogState(() => isSubmitting = true);
                    final error = await ref
                        .read(parentAuthProvider.notifier)
                        .login(emailCtrl.text.trim(), passwordCtrl.text);
                    if (error != null) {
                      setDialogState(() => isSubmitting = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(error)));
                      }
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) Navigator.pushNamed(context, '/parent-portal');
                  },
            child: isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Se connecter', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}
