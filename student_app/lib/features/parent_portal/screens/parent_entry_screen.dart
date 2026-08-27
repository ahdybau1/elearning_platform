import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/parent_auth_provider.dart';

/// §17 du cahier des charges : point d'entrée réel de l'Espace Parent — un vrai compte séparé
/// (`parent_accounts`, session Supabase dédiée via `parentAuthProvider`), atteint directement depuis
/// RoleSelectionScreen, jamais depuis l'intérieur de l'app élève. Une fois connecté, AppRootGate
/// (main.dart) bascule automatiquement vers ParentDashboardScreen — pas de navigation manuelle ici.
class ParentEntryScreen extends ConsumerStatefulWidget {
  const ParentEntryScreen({super.key});

  @override
  ConsumerState<ParentEntryScreen> createState() => _ParentEntryScreenState();
}

class _ParentEntryScreenState extends ConsumerState<ParentEntryScreen> {
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _linkCodeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _linkCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

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

    if (!mounted) return;

    if (error == kParentSignUpNeedsEmailConfirmation) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte créé — confirmez votre email puis reconnectez-vous.')),
      );
      return;
    }
    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
      return;
    }

    setState(() => _isSubmitting = false);
    // Succès : AppRootGate (main.dart) réagit automatiquement à parentAuthProvider et bascule vers
    // ParentDashboardScreen — un simple pop suffit à révéler ce contenu déjà à jour dessous.
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary),
                      tooltip: 'Retour',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.colors.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.family_restroom_rounded, color: context.colors.accentAmber, size: 34),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Espace Parent',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Créez votre propre compte parent pour suivre la scolarité de votre enfant.'
                        : 'Connectez-vous avec votre compte parent.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isSignUp) ...[
                          Row(
                            children: [
                              Expanded(child: _field(_firstNameCtrl, 'Prénom', validator: _requiredValidator)),
                              const SizedBox(width: 10),
                              Expanded(child: _field(_lastNameCtrl, 'Nom', validator: _requiredValidator)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _field(_phoneCtrl, 'Téléphone', keyboardType: TextInputType.phone),
                          const SizedBox(height: 16),
                        ],
                        _field(_emailCtrl, 'Adresse email', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
                        const SizedBox(height: 16),
                        _field(_passwordCtrl, 'Mot de passe', obscure: true, validator: _requiredValidator),
                        if (_isSignUp) ...[
                          const SizedBox(height: 16),
                          _field(
                            _linkCodeCtrl,
                            'Code de liaison (donné par votre enfant, optionnel)',
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.accentRose.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.colors.accentRose.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: context.colors.accentRose, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(fontSize: 12, color: context.colors.accentRose),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.accentAmber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  _isSignUp ? 'Créer mon compte' : 'Se connecter',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Vous avez déjà un compte parent ? Se connecter' : 'Pas encore de compte parent ? Créer un compte',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.accentPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null;
  String? _emailValidator(String? v) => (v == null || !v.contains('@')) ? 'Adresse email invalide' : null;

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
        fillColor: context.colors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }
}
