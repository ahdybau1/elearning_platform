import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/student_theme.dart';
import 'parent_auth_provider.dart';

/// Point d'entrée unique vers l'Espace Parent (§17 du cahier des charges), utilisé depuis
/// `profile_switcher_screen.dart` et `main_navigation_screen.dart`. Remplace l'ancien PIN codé en
/// dur : si une session parent réelle est déjà active (restaurée automatiquement au démarrage,
/// voir `ParentAuthNotifier`), on navigue directement — « sans réauthentification constante » comme
/// l'exige le CDC. Sinon, un vrai formulaire (connexion, ou auto-inscription — le parent crée lui-
/// même son compte, un admin peut aussi le faire depuis admin_app).
Future<void> openParentSpace(BuildContext context, WidgetRef ref) async {
  final parentState = ref.read(parentAuthProvider);
  if (parentState.isAuthenticated) {
    if (context.mounted) Navigator.pushNamed(context, '/parent-portal');
    return;
  }
  await showDialog(
    context: context,
    builder: (ctx) => ParentAuthDialog(
      onSuccess: () {
        Navigator.pop(ctx);
        Navigator.pushNamed(context, '/parent-portal');
      },
    ),
  );
}

/// Dialogue de connexion/auto-inscription parent, réutilisé tel quel par `main_navigation_screen.dart`
/// (bascule vers la page Espace Parent au lieu de pousser une route) — un seul endroit à maintenir
/// pour ce formulaire qui a deux modes (connexion / inscription) plutôt que deux copies quasi
/// identiques.
class ParentAuthDialog extends ConsumerStatefulWidget {
  const ParentAuthDialog({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  ConsumerState<ParentAuthDialog> createState() => _ParentAuthDialogState();
}

class _ParentAuthDialogState extends ConsumerState<ParentAuthDialog> {
  bool _isSignUp = false;
  bool _isSubmitting = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _linkCodeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.card,
      title: Row(
        children: [
          Icon(Icons.family_restroom_rounded, color: context.colors.accentAmber),
          const SizedBox(width: 10),
          Text('Espace Parent', style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp
                    ? 'Créez votre propre compte parent pour suivre la scolarité de votre enfant.'
                    : 'Connectez-vous avec votre compte parent.',
                style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (_isSignUp) ...[
                Row(
                  children: [
                    Expanded(child: _field(_firstNameCtrl, 'Prénom', validator: _requiredValidator)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_lastNameCtrl, 'Nom', validator: _requiredValidator)),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_phoneCtrl, 'Téléphone', keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
              ],
              _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
              const SizedBox(height: 12),
              _field(_passwordCtrl, 'Mot de passe', obscure: true, validator: _requiredValidator),
              if (_isSignUp) ...[
                const SizedBox(height: 12),
                _field(
                  _linkCodeCtrl,
                  'Code de liaison (donné par votre enfant, optionnel)',
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _isSubmitting ? null : () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'Vous avez déjà un compte parent ? Se connecter' : 'Pas encore de compte parent ? Créer un compte',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.accentPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: context.colors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentAmber),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(_isSignUp ? 'Créer mon compte' : 'Se connecter', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null;
  String? _emailValidator(String? v) => (v == null || !v.contains('@')) ? 'Email invalide' : null;

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool obscure = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textSecondary),
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final notifier = ref.read(parentAuthProvider.notifier);
    final String? error;
    if (_isSignUp) {
      error = await notifier.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        linkCode: _linkCodeCtrl.text.trim().isEmpty ? null : _linkCodeCtrl.text.trim(),
      );
    } else {
      error = await notifier.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    }

    if (error == kParentSignUpNeedsEmailConfirmation) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé — confirmez votre email puis reconnectez-vous.')),
        );
      }
      return;
    }
    if (error != null) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    widget.onSuccess();
  }
}
