import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/app_root_providers.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../widgets/auth_ui.dart';

class StudentLoginScreen extends ConsumerStatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  ConsumerState<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends ConsumerState<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  /// Le compte existe mais l'email n'a jamais été confirmé : on propose de renvoyer le lien.
  bool _needsEmailConfirmation = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
      _needsEmailConfirmation = false;
    });

    final error = await ref
        .read(studentAuthProvider.notifier)
        .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (error == kSignInEmailNotConfirmed) {
      setState(() => _needsEmailConfirmation = true);
      return;
    }
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    // Succès : StudentAuthGate (main.dart) bascule tout seul vers l'app. Cet écran peut avoir été
    // empilé (« Ajouter un compte », « Code oublié ? ») : on revient à la racine déjà à jour.
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    final error = await ref.read(studentAuthProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _isGoogleLoading = false;
      _errorMessage = error;
    });
  }

  Future<void> _resendConfirmation() async {
    final error = await ref.read(studentAuthProvider.notifier).resendSignUpEmail(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _errorMessage = error;
      if (error == null) {
        _needsEmailConfirmation = false;
        _infoMessage = 'Lien de confirmation renvoyé à ${_emailCtrl.text.trim()}. Pensez à regarder dans les spams.';
      }
    });
  }

  /// Aucun parcours de récupération n'existait avant : un élève ayant oublié son mot de passe
  /// n'avait strictement aucun recours. Utilise l'API standard GoTrue — jamais de simulation, et
  /// le message reste générique pour ne jamais confirmer/infirmer l'existence d'un compte.
  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    var isSending = false;
    String? errorMessage;
    var sent = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(
            'Mot de passe oublié',
            style: TextStyle(color: context.colors.textPrimary),
          ),
          content: sent
              ? Text(
                  'Si un compte existe avec cette adresse, un email de réinitialisation vient de lui être envoyé. Vérifiez aussi vos spams.',
                  style: TextStyle(color: context.colors.textSecondary),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Saisissez votre adresse email : un lien de réinitialisation vous sera envoyé.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Adresse email',
                        labelStyle: TextStyle(color: context.colors.textSecondary),
                        filled: true,
                        fillColor: context.colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusMedium,
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: context.colors.accentRose, fontSize: 12),
                      ),
                    ],
                  ],
                ),
          actions: [
            if (sent)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fermer'),
              )
            else ...[
              TextButton(
                onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                child: Text(
                  'Annuler',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accentPrimary,
                  foregroundColor: Colors.black,
                ),
                onPressed: isSending
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (!email.contains('@')) {
                          setDialogState(() => errorMessage = 'Adresse email invalide.');
                          return;
                        }
                        setDialogState(() {
                          isSending = true;
                          errorMessage = null;
                        });
                        final error = await ref
                            .read(studentAuthProvider.notifier)
                            .requestPasswordReset(email);
                        setDialogState(() {
                          isSending = false;
                          if (error != null) {
                            errorMessage = error;
                          } else {
                            sent = true;
                          }
                        });
                      },
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Envoyer'),
              ),
            ],
          ],
        ),
      ),
    );
    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Empilé par-dessus le déverrouillage par code → simple pop. Racine du parcours élève (juste
    // après « Je suis élève ») → on réinitialise le choix de rôle (voir AppRootGate, main.dart).
    final canPop = Navigator.canPop(context);
    return AuthScaffold(
      topBar: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: c.textSecondary),
            tooltip: 'Retour',
            onPressed: () {
              if (canPop) {
                Navigator.pop(context);
              } else {
                ref.read(hasChosenStudentRoleProvider.notifier).state = false;
              }
            },
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthLogo(size: 64),
              const SizedBox(height: 20),
              Text('Bon retour !',
                  style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour retrouver vos cours, exercices et annales.',
                style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: c.textSecondary),
              ),
              const SizedBox(height: 28),
              GoogleAuthButton(onPressed: _isSubmitting ? null : _continueWithGoogle, isLoading: _isGoogleLoading),
              const SizedBox(height: 20),
              const OrDivider(label: 'ou avec votre email'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                style: TextStyle(color: c.textPrimary),
                decoration: authInputDecoration(context, label: 'Adresse email', icon: Icons.alternate_email_rounded),
                validator: emailValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                style: TextStyle(color: c.textPrimary),
                decoration: authInputDecoration(
                  context,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: c.textSecondary),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _showForgotPasswordDialog,
                  child: Text('Mot de passe oublié ?',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.accentPrimary)),
                ),
              ),
              if (_needsEmailConfirmation) ...[
                const SizedBox(height: 8),
                AuthMessageBox.info(
                  title: 'Confirmez d\'abord votre adresse email',
                  message: 'Ouvrez le lien reçu au moment de l\'inscription (pensez aux spams). Le lien a expiré ou a disparu ?',
                  actions: [TextButton(onPressed: _resendConfirmation, child: const Text('Renvoyer le lien'))],
                ),
              ],
              if (_infoMessage != null) ...[
                const SizedBox(height: 8),
                AuthMessageBox.success(message: _infoMessage!),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                AuthMessageBox.error(message: _errorMessage!),
              ],
              const SizedBox(height: 20),
              AuthPrimaryButton(label: 'Se connecter', isLoading: _isSubmitting, onPressed: _submit),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Pas encore de compte ?', style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/onboarding'),
                    child: Text('Créer un compte',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.accentPrimary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
