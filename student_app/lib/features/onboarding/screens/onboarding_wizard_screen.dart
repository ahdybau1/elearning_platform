import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';

/// Inscription réelle. Si l'utilisateur n'a pas encore de session (nouveau visiteur), le parcours
/// commence par la création du compte (email + mot de passe réels, Supabase Auth) puis descend
/// l'arbre académique réel jusqu'à une classe. Si l'utilisateur est déjà connecté (ajout d'un
/// profil supplémentaire depuis le sélecteur de profils — voir §2.3 du cahier des charges, 1 compte
/// peut suivre plusieurs classes), l'étape compte est sautée.
class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  final _accountFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscurePassword = true;

  bool _accountStepDone = false;
  final List<StudentAcademicNode> _selectedPath = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _needsAccountStep => !ref.read(studentAuthProvider).isAuthenticated;

  void _goBack() {
    setState(() {
      _errorMessage = null;
      if (_selectedPath.isNotEmpty) {
        _selectedPath.removeLast();
      } else if (_needsAccountStep) {
        _accountStepDone = false;
      }
    });
  }

  void _submitAccountStep() {
    if (!_accountFormKey.currentState!.validate()) return;
    setState(() {
      _accountStepDone = true;
      _errorMessage = null;
    });
  }

  Future<void> _submitFinal(StudentAcademicNode leaf) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final service = ref.read(studentSupabaseServiceProvider);
    final countryId = leaf.countryId;
    if (countryId == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Nœud académique invalide (pays introuvable).';
      });
      return;
    }

    final schoolYear = await service.fetchCurrentSchoolYear(countryId);
    if (schoolYear == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Aucune année scolaire active n\'a été configurée par l\'administration pour ce pays. Réessayez plus tard.';
      });
      return;
    }

    final notifier = ref.read(studentAuthProvider.notifier);

    if (_needsAccountStep) {
      final signUpError = await notifier.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );

      if (signUpError == kSignUpNeedsEmailConfirmation) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: StudentTheme.cardDark,
            title: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: StudentTheme.accentPrimary),
                const SizedBox(width: 10),
                Text('Confirmez votre email',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Un email de confirmation a été envoyé à ${_emailCtrl.text.trim()}. Une fois confirmé, revenez vous connecter pour terminer votre inscription (le choix de votre classe sera repris automatiquement).',
              style: GoogleFonts.inter(color: StudentTheme.textSecondary, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: StudentTheme.accentPrimary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (signUpError != null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = signUpError;
        });
        return;
      }
    }

    final addProfileError = await notifier.addProfile(
      classNodeId: leaf.id,
      schoolYear: schoolYear,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (addProfileError != null) {
      setState(() => _errorMessage = addProfileError);
      return;
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final needsAccount = _needsAccountStep;
    final showAccountStep = needsAccount && !_accountStepDone;
    final canGoBack = showAccountStep ? false : (_selectedPath.isNotEmpty || needsAccount);

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canGoBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isSubmitting ? null : _goBack,
                      icon: const Icon(Icons.arrow_back_rounded, color: StudentTheme.textSecondary, size: 18),
                      label: Text('Précédent', style: GoogleFonts.inter(color: StudentTheme.textSecondary)),
                    ),
                  ),
                if (_selectedPath.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedPath
                        .map((n) => Chip(
                              label: Text(n.name, style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                              backgroundColor: StudentTheme.surfaceDark,
                              side: const BorderSide(color: StudentTheme.borderDark),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: showAccountStep ? _buildAccountStep() : _buildTreeOrSummaryStep(),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StudentTheme.accentRose.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StudentTheme.accentRose.withOpacity(0.4)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.accentRose),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountStep() {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenue sur votre Plateforme d\'Excellence',
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre compte pour commencer.',
            style: GoogleFonts.inter(fontSize: 14, color: StudentTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _textField(_firstNameCtrl, 'Prénom', validator: _requiredValidator)),
              const SizedBox(width: 12),
              Expanded(child: _textField(_lastNameCtrl, 'Nom', validator: _requiredValidator)),
            ],
          ),
          const SizedBox(height: 16),
          _textField(_emailCtrl, 'Adresse email', keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Adresse email invalide' : null),
          const SizedBox(height: 16),
          _textField(_phoneCtrl, 'Numéro de téléphone (Mobile Money)', keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              labelStyle: const TextStyle(color: StudentTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: StudentTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: StudentTheme.cardDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe',
              labelStyle: const TextStyle(color: StudentTheme.textSecondary),
              filled: true,
              fillColor: StudentTheme.cardDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v != _passwordCtrl.text) ? 'Les mots de passe ne correspondent pas' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentTheme.accentPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _submitAccountStep,
              child: Text('Continuer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null;

  Widget _textField(TextEditingController ctrl, String label,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: StudentTheme.textSecondary),
        filled: true,
        fillColor: StudentTheme.cardDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }

  Widget _buildTreeOrSummaryStep() {
    final parentId = _selectedPath.isEmpty ? null : _selectedPath.last.id;
    final childrenAsync = ref.watch(studentAcademicChildrenProvider(parentId));

    return childrenAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      )),
      error: (err, _) => Text('Erreur : $err', style: const TextStyle(color: Colors.red)),
      data: (children) {
        if (children.isEmpty) {
          if (_selectedPath.isEmpty) {
            return Text(
              'Aucune classe n\'a encore été configurée par l\'administration. Réessayez plus tard.',
              style: GoogleFonts.inter(color: StudentTheme.textSecondary),
            );
          }
          return _buildSummaryStep(_selectedPath.last);
        }
        return _buildNodePicker(children);
      },
    );
  }

  Widget _buildNodePicker(List<StudentAcademicNode> children) {
    final title = _selectedPath.isEmpty ? 'Votre Pays' : 'Sélectionnez : ${_nodeTypeLabel(children.first.nodeType)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          'Le programme, les cours et les annales seront calibrés sur votre choix.',
          style: GoogleFonts.inter(fontSize: 13, color: StudentTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        ...children.map((node) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: StudentTheme.borderDark),
              ),
              tileColor: StudentTheme.cardDark,
              leading: const Icon(Icons.chevron_right_rounded, color: StudentTheme.accentPrimary),
              title: Text(node.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              onTap: () => setState(() => _selectedPath.add(node)),
            ),
          );
        }),
      ],
    );
  }

  String _nodeTypeLabel(String nodeType) {
    switch (nodeType) {
      case 'country':
        return 'Pays';
      case 'section':
        return 'Section';
      case 'education_type':
        return 'Type d\'enseignement';
      case 'class':
        return 'Classe';
      case 'series':
        return 'Série';
      default:
        return nodeType;
    }
  }

  Widget _buildSummaryStep(StudentAcademicNode leaf) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: StudentTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudentTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StudentTheme.accentEmerald.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: StudentTheme.accentEmerald, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prêt à Exceller !',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Votre espace de révision personnalisé est prêt.',
                        style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: StudentTheme.borderDark),
          const SizedBox(height: 14),
          if (_needsAccountStep) ...[
            _buildSummaryRow('Élève', '${_firstNameCtrl.text} ${_lastNameCtrl.text}'),
            _buildSummaryRow('Email', _emailCtrl.text),
          ],
          _buildSummaryRow('Classe', leaf.name),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentTheme.accentPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : () => _submitFinal(leaf),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _needsAccountStep ? 'Créer mon compte et commencer' : 'Ajouter ce profil',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: StudentTheme.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
