import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';

/// Trois cas possibles au démarrage de l'assistant, selon l'état réel de la session (voir
/// StudentAuthState.hasSession/isAuthenticated) :
/// - [fullSignUp] : aucune session — nouveau visiteur, formulaire complet (email + mot de passe).
/// - [completeProfile] : session Supabase Auth réelle mais aucune ligne `accounts` (ex. un admin
///   qui teste l'app élève, ou une inscription reprise après confirmation email) — juste
///   prénom/nom/téléphone, pas de mot de passe à redemander.
/// - [none] : compte élève déjà complet — ajout d'un profil supplémentaire (§2.3 du cahier des
///   charges, 1 compte peut suivre plusieurs classes), l'étape "identité" est sautée entièrement.
enum _AccountStepKind { fullSignUp, completeProfile, none }

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
  final _schoolNameCtrl = TextEditingController();
  DateTime? _birthDate;
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
    _schoolNameCtrl.dispose();
    super.dispose();
  }

  _AccountStepKind get _accountStepKind {
    final authState = ref.read(studentAuthProvider);
    if (!authState.hasSession) return _AccountStepKind.fullSignUp;
    if (!authState.isAuthenticated) return _AccountStepKind.completeProfile;
    return _AccountStepKind.none;
  }

  void _goBack() {
    setState(() {
      _errorMessage = null;
      if (_selectedPath.isNotEmpty) {
        _selectedPath.removeLast();
      } else if (_accountStepKind != _AccountStepKind.none) {
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
    final accountStepKind = _accountStepKind;

    if (accountStepKind == _AccountStepKind.fullSignUp) {
      final signUpError = await notifier.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        birthDate: _birthDate,
        schoolName: _schoolNameCtrl.text.trim().isEmpty ? null : _schoolNameCtrl.text.trim(),
      );

      if (signUpError == kSignUpNeedsEmailConfirmation) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.colors.card,
            title: Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: context.colors.accentPrimary),
                const SizedBox(width: 10),
                Text('Confirmez votre email',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Un email de confirmation a été envoyé à ${_emailCtrl.text.trim()}. Une fois confirmé, revenez vous connecter pour terminer votre inscription (le choix de votre classe sera repris automatiquement).',
              style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentPrimary),
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
    } else if (accountStepKind == _AccountStepKind.completeProfile) {
      final completeError = await notifier.completeProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        birthDate: _birthDate,
        schoolName: _schoolNameCtrl.text.trim().isEmpty ? null : _schoolNameCtrl.text.trim(),
      );
      if (completeError != null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = completeError;
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
    final accountStepKind = _accountStepKind;
    final needsAccount = accountStepKind != _AccountStepKind.none;
    final showAccountStep = needsAccount && !_accountStepDone;
    final canGoBack = showAccountStep ? false : (_selectedPath.isNotEmpty || needsAccount);

    return Scaffold(
      backgroundColor: context.colors.background,
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
                      icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary, size: 18),
                      label: Text('Précédent', style: GoogleFonts.inter(color: context.colors.textSecondary)),
                    ),
                  ),
                if (_selectedPath.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedPath
                        .map((n) => Chip(
                              label: Text(n.name, style: GoogleFonts.inter(fontSize: 11, color: context.colors.textPrimary)),
                              backgroundColor: context.colors.surface,
                              side: BorderSide(color: context.colors.border),
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
                        color: context.colors.accentRose.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.accentRose.withOpacity(0.4)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(fontSize: 12, color: context.colors.accentRose),
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
    final isCompleteProfile = _accountStepKind == _AccountStepKind.completeProfile;
    final sessionEmail = ref.read(studentAuthProvider).sessionEmail;

    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCompleteProfile ? 'Terminez votre profil élève' : 'Bienvenue sur votre Plateforme d\'Excellence',
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleteProfile
                ? 'Vous êtes déjà connecté (${sessionEmail ?? ''}) — plus qu\'une étape avant de choisir votre classe.'
                : 'Créez votre compte pour commencer.',
            style: GoogleFonts.inter(fontSize: 14, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _textField(_firstNameCtrl, 'Prénom', validator: _requiredValidator)),
              const SizedBox(width: 12),
              Expanded(child: _textField(_lastNameCtrl, 'Nom', validator: _requiredValidator)),
            ],
          ),
          if (!isCompleteProfile) ...[
            const SizedBox(height: 16),
            _textField(_emailCtrl, 'Adresse email', keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Adresse email invalide' : null),
          ],
          const SizedBox(height: 16),
          _textField(_phoneCtrl, 'Numéro de téléphone (Mobile Money)', keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _textField(_schoolNameCtrl, 'Établissement fréquenté (optionnel)'),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(DateTime.now().year - 15),
                firstDate: DateTime(DateTime.now().year - 100),
                lastDate: DateTime.now(),
                helpText: 'Date de naissance (optionnel)',
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date de naissance (optionnel)',
                labelStyle: TextStyle(color: context.colors.textSecondary),
                filled: true,
                fillColor: context.colors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: Icon(Icons.cake_outlined, color: context.colors.textSecondary),
              ),
              child: Text(
                _birthDate == null
                    ? 'Pour vous souhaiter votre anniversaire 🎂'
                    : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                style: TextStyle(color: _birthDate == null ? context.colors.textMuted : context.colors.textPrimary),
              ),
            ),
          ),
          if (!isCompleteProfile) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(color: context.colors.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: context.colors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscurePassword,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                labelStyle: TextStyle(color: context.colors.textSecondary),
                filled: true,
                fillColor: context.colors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v != _passwordCtrl.text) ? 'Les mots de passe ne correspondent pas' : null,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
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
        labelStyle: TextStyle(color: context.colors.textSecondary),
        filled: true,
        fillColor: context.colors.card,
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
              style: GoogleFonts.inter(color: context.colors.textSecondary),
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
        Text(title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Le programme, les cours et les annales seront calibrés sur votre choix.',
          style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 20),
        ...children.map((node) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.colors.border),
              ),
              tileColor: context.colors.card,
              leading: Icon(Icons.chevron_right_rounded, color: context.colors.accentPrimary),
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
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.accentEmerald.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rocket_launch_rounded, color: context.colors.accentEmerald, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prêt à Exceller !',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Votre espace de révision personnalisé est prêt.',
                        style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: context.colors.border),
          const SizedBox(height: 14),
          if (_accountStepKind != _AccountStepKind.none) ...[
            _buildSummaryRow('Élève', '${_firstNameCtrl.text} ${_lastNameCtrl.text}'),
            _buildSummaryRow(
              'Email',
              _accountStepKind == _AccountStepKind.completeProfile
                  ? (ref.read(studentAuthProvider).sessionEmail ?? '')
                  : _emailCtrl.text,
            ),
          ],
          _buildSummaryRow('Classe', leaf.name),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
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
                      switch (_accountStepKind) {
                        _AccountStepKind.fullSignUp => 'Créer mon compte et commencer',
                        _AccountStepKind.completeProfile => 'Terminer mon profil et commencer',
                        _AccountStepKind.none => 'Ajouter ce profil',
                      },
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
          Text(label, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(color: context.colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
