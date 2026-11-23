import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/theme/student_theme.dart';
import '../widgets/auth_ui.dart';

/// Affiché quand l'élève ouvre le lien « mot de passe oublié » reçu par email (session de
/// récupération Supabase). Sans cet écran, le lien ouvrait l'app sans jamais permettre de choisir
/// un nouveau mot de passe.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final error = await ref.read(studentAuthProvider.notifier).completePasswordRecovery(_passwordCtrl.text);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(studentAuthProvider).sessionEmail ?? '';
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthLogo(size: 72),
            const SizedBox(height: 24),
            Text(
              'Choisissez un nouveau mot de passe',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              email.isEmpty ? 'Il servira à vos prochaines connexions.' : 'Pour le compte $email.',
              style: GoogleFonts.inter(fontSize: 14, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              style: TextStyle(color: context.colors.textPrimary),
              decoration: authInputDecoration(
                context,
                label: 'Nouveau mot de passe',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscure ? 'Afficher' : 'Masquer',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: context.colors.textSecondary),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: passwordValidator,
            ),
            const SizedBox(height: 10),
            PasswordStrengthMeter(password: _passwordCtrl.text),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              style: TextStyle(color: context.colors.textPrimary),
              decoration: authInputDecoration(context, label: 'Confirmer le mot de passe', icon: Icons.lock_reset_rounded),
              validator: (v) => v != _passwordCtrl.text ? 'Les deux mots de passe ne correspondent pas' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthMessageBox.error(message: _error!),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Enregistrer et continuer',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSubmitting ? null : () => ref.read(studentAuthProvider.notifier).cancelPasswordRecovery(),
              child: Text('Annuler', style: GoogleFonts.inter(color: context.colors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
