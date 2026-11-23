import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../widgets/auth_ui.dart';
import '../widgets/phone_country.dart';

/// Trois situations possibles à l'ouverture de l'assistant, selon l'état réel de la session :
/// - [fullSignUp] : aucune session — nouveau visiteur (identité → compte → classe → récapitulatif).
/// - [completeProfile] : session réelle mais pas encore de ligne `accounts` (retour de Google, admin
///   qui teste l'app…) — identité → classe → récapitulatif, sans mot de passe.
/// - [none] : compte déjà complet — ajout d'une classe supplémentaire (§2.3 du cahier des charges).
enum _AccountStepKind { fullSignUp, completeProfile, none }

enum _Step { identity, account, classe }

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  final _identityFormKey = GlobalKey<FormState>();
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
  /// 'masculin' | 'feminin' (obligatoire à l'inscription, demande du porteur).
  String? _gender;
  PhoneCountry _phoneCountry = PhoneCountry.cameroon;
  /// Famille de série choisie (scientifique / littéraire / artistique) avant la liste des séries.
  String? _seriesFamily;

  int _stepIndex = 0;
  final List<StudentAcademicNode> _selectedPath = [];
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _emailAlreadyUsed = false;
  String? _infoMessage;
  /// Adresse à laquelle l'email de confirmation vient d'être envoyé : l'assistant affiche alors
  /// l'écran « Vérifiez votre boîte mail » au lieu des étapes.
  String? _emailSentTo;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => setState(() {}));
    _prefillFromSession();
  }

  /// Retour de Google : prénom et nom pré-remplis à partir du profil Google, l'élève n'a plus qu'à
  /// vérifier et choisir sa classe.
  void _prefillFromSession() {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (meta == null) return;
    String read(String key) => (meta[key] as String?)?.trim() ?? '';
    var first = read('first_name');
    var last = read('last_name');
    if (first.isEmpty && last.isEmpty) {
      first = read('given_name');
      last = read('family_name');
    }
    if (first.isEmpty && last.isEmpty) {
      final full = read('full_name').isNotEmpty ? read('full_name') : read('name');
      final parts = full.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        first = parts.first;
        last = parts.skip(1).join(' ');
      }
    }
    _firstNameCtrl.text = first;
    _lastNameCtrl.text = last;
  }

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

  List<_Step> get _steps => switch (_accountStepKind) {
        _AccountStepKind.fullSignUp => const [_Step.identity, _Step.account, _Step.classe],
        _AccountStepKind.completeProfile => const [_Step.identity, _Step.classe],
        _AccountStepKind.none => const [_Step.classe],
      };

  _Step get _currentStep => _steps[_stepIndex.clamp(0, _steps.length - 1)];

  String? get _normalizedPhone => _phoneCountry.international(_phoneCtrl.text);

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    final form = switch (_currentStep) {
      _Step.identity => _identityFormKey,
      _Step.account => _accountFormKey,
      _Step.classe => null,
    };
    if (form != null && !(form.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      if (_stepIndex < _steps.length - 1) _stepIndex++;
    });
  }

  void _back() {
    if (_stepIndex == 0 && _selectedPath.isEmpty && _seriesFamily == null) {
      _goToLogin();
      return;
    }
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      if (_currentStep == _Step.classe && _seriesFamily != null) {
        _seriesFamily = null;
      } else if (_currentStep == _Step.classe && _selectedPath.isNotEmpty) {
        _selectedPath.removeLast();
      } else if (_stepIndex > 0) {
        _stepIndex--;
      }
    });
  }

  /// L'assistant est empilé par-dessus l'écran de connexion (« Créer un compte ») : y revenir.
  void _goToLogin() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  bool get _canGoBack =>
      _stepIndex > 0 || _selectedPath.isNotEmpty || _seriesFamily != null || Navigator.canPop(context);

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    final error = await ref.read(studentAuthProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _isGoogleLoading = false;
      _errorMessage = error;
    });
  }

  Future<void> _resendEmail() async {
    final email = _emailSentTo;
    if (email == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    final error = await ref.read(studentAuthProvider.notifier).resendSignUpEmail(email);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
      _infoMessage = error == null ? 'Email renvoyé. Il peut mettre une à deux minutes à arriver.' : null;
    });
  }

  Future<void> _sendPasswordReset() async {
    final error = await ref.read(studentAuthProvider.notifier).requestPasswordReset(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _errorMessage = error;
      _infoMessage = error == null
          ? 'Si un compte existe pour ${_emailCtrl.text.trim()}, un lien de réinitialisation vient d\'être envoyé.'
          : null;
    });
  }

  Future<void> _submitFinal(StudentAcademicNode leaf) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
      _emailAlreadyUsed = false;
    });

    final service = ref.read(studentSupabaseServiceProvider);
    final countryId = leaf.countryId;
    if (countryId == null) {
      return _fail('Cette classe est mal configurée (pays introuvable). Choisissez-en une autre ou contactez le support.');
    }

    final schoolYear = await service.fetchCurrentSchoolYear(countryId);
    if (schoolYear == null) {
      return _fail('Aucune année scolaire n\'est encore ouverte pour ce pays. Réessayez plus tard.');
    }

    // §2.3 du CDC : avertissement (pas un blocage) si la même personne semble déjà inscrite dans
    // cette classe sur un autre compte. N'a de sens qu'avec une date de naissance.
    if (_birthDate != null && _firstNameCtrl.text.trim().isNotEmpty && _lastNameCtrl.text.trim().isNotEmpty) {
      final isDuplicate = await service.checkDuplicatePersonProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        birthDate: _birthDate!,
        classNodeId: leaf.id,
        excludeAccountId: ref.read(studentAuthProvider).account?.id,
      );
      if (isDuplicate && mounted && !await _confirmDuplicate()) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    final notifier = ref.read(studentAuthProvider.notifier);
    final kind = _accountStepKind;
    final school = _schoolNameCtrl.text.trim().isEmpty ? null : _schoolNameCtrl.text.trim();

    if (kind == _AccountStepKind.fullSignUp) {
      final result = await notifier.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _normalizedPhone,
        birthDate: _birthDate,
        schoolName: school,
        gender: _gender,
        pendingClassNodeId: leaf.id,
        pendingSchoolYear: schoolYear,
      );
      if (!mounted) return;
      if (result == kSignUpNeedsEmailConfirmation) {
        setState(() {
          _isSubmitting = false;
          _emailSentTo = _emailCtrl.text.trim();
        });
        return;
      }
      if (result == kSignUpEmailAlreadyUsed) {
        setState(() {
          _isSubmitting = false;
          _emailAlreadyUsed = true;
          _stepIndex = _steps.indexOf(_Step.account);
        });
        return;
      }
      if (result != null) return _fail(result);
    } else if (kind == _AccountStepKind.completeProfile) {
      final error = await notifier.completeProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _normalizedPhone,
        birthDate: _birthDate,
        schoolName: school,
        gender: _gender,
      );
      if (error != null) return _fail(error);
    }

    // Le profil de la classe a pu être créé automatiquement à l'inscription (voir
    // StudentAuthNotifier._resumePendingSignUp) : on ne le recrée pas.
    final alreadyHasClass = ref.read(studentAuthProvider).profiles.any((p) => p.classNodeId == leaf.id);
    if (!alreadyHasClass) {
      final error = await notifier.addProfile(classNodeId: leaf.id, schoolYear: schoolYear);
      if (error != null) return _fail(error);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    // StudentAuthGate (main.dart) bascule tout seul vers l'app dès que `profiles` n'est plus vide ;
    // on ne dépile que si cet écran a réellement été empilé.
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = message;
    });
  }

  Future<bool> _confirmDuplicate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.person_search_rounded, color: context.colors.accentAmber, size: 32),
        title: Text('Déjà inscrit ?',
            style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Un élève avec les mêmes prénom, nom et date de naissance est déjà inscrit dans cette classe '
          'avec un autre compte. Si c\'est vous, connectez-vous plutôt avec ce compte. '
          'Si vous êtes jumeaux dans la même classe, continuez.',
          style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: context.colors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.accentAmber, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer quand même'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // ─── Construction ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_emailSentTo != null) {
      return AuthScaffold(child: _buildEmailSentView(_emailSentTo!));
    }

    final steps = _steps;
    final parentId = _selectedPath.isEmpty ? null : _selectedPath.last.id;
    final childrenAsync = _currentStep == _Step.classe ? ref.watch(studentAcademicChildrenProvider(parentId)) : null;
    final atLeaf = _currentStep == _Step.classe &&
        _selectedPath.isNotEmpty &&
        (childrenAsync?.valueOrNull?.isEmpty ?? false);
    final totalSteps = steps.length + 1; // + récapitulatif
    final displayIndex = atLeaf ? steps.length : _stepIndex;

    return AuthScaffold(
      maxWidth: 520,
      topBar: _buildTopBar(displayIndex, totalSteps),
      bottomBar: _currentStep != _Step.classe
          ? AuthPrimaryButton(label: 'Continuer', icon: Icons.arrow_forward_rounded, onPressed: _next)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('${_currentStep.name}-${_selectedPath.length}-$atLeaf'),
              child: switch (_currentStep) {
                _Step.identity => _buildIdentityStep(),
                _Step.account => _buildAccountStep(),
                _Step.classe => atLeaf ? _buildReviewStep(_selectedPath.last) : _buildClassStep(childrenAsync!),
              },
            ),
          ),
          if (_infoMessage != null) ...[
            const SizedBox(height: 16),
            AuthMessageBox.success(message: _infoMessage!),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthMessageBox.error(message: _errorMessage!),
          ],
          if (_accountStepKind == _AccountStepKind.fullSignUp && _stepIndex == 0) ...[
            const SizedBox(height: 20),
            _buildAlreadyHaveAccount(),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar(int index, int total) {
    final c = context.colors;
    const labels = {
      _Step.identity: 'Vous',
      _Step.account: 'Votre compte',
      _Step.classe: 'Votre classe',
    };
    final label = index >= _steps.length ? 'Récapitulatif' : labels[_steps[index]]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Retour',
                onPressed: _canGoBack && !_isSubmitting ? _back : null,
                icon: Icon(Icons.arrow_back_rounded, color: c.textSecondary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Étape ${index + 1} sur $total · $label',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (index + 1) / total),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader(String title, String subtitle) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 28, height: 1.2, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: c.textSecondary)),
        ],
      ),
    );
  }

  // Étape 1 — identité
  Widget _buildIdentityStep() {
    final kind = _accountStepKind;
    final c = context.colors;
    final sessionEmail = ref.read(studentAuthProvider).sessionEmail;
    return Form(
      key: _identityFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kind == _AccountStepKind.fullSignUp) ...[
              const AuthLogo(size: 56),
              const SizedBox(height: 20),
              _stepHeader('Créez votre compte élève', 'Gratuit, en moins de deux minutes.'),
              GoogleAuthButton(onPressed: _continueWithGoogle, isLoading: _isGoogleLoading, label: 'S\'inscrire avec Google'),
              const SizedBox(height: 20),
              const OrDivider(label: 'ou avec votre email'),
              const SizedBox(height: 20),
            ] else
              _stepHeader(
                'Faisons connaissance',
                sessionEmail == null
                    ? 'Vérifiez vos informations avant de choisir votre classe.'
                    : 'Connecté avec $sessionEmail. Vérifiez vos informations avant de choisir votre classe.',
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final first = TextFormField(
                  controller: _firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  style: TextStyle(color: c.textPrimary),
                  decoration: authInputDecoration(context, label: 'Prénom', icon: Icons.person_outline_rounded),
                  validator: requiredValidator,
                );
                final last = TextFormField(
                  controller: _lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  style: TextStyle(color: c.textPrimary),
                  decoration: authInputDecoration(context, label: 'Nom'),
                  validator: requiredValidator,
                );
                if (constraints.maxWidth < 380) {
                  return Column(children: [first, const SizedBox(height: 14), last]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: last)],
                );
              },
            ),
            const SizedBox(height: 14),
            _buildGenderField(),
            const SizedBox(height: 14),
            _buildBirthDateField(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _schoolNameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: c.textPrimary),
              decoration: authInputDecoration(
                context,
                label: 'Établissement (facultatif)',
                icon: Icons.apartment_rounded,
                hint: 'Ex. Lycée Bilingue de Yaoundé',
              ),
            ),
            if (kind == _AccountStepKind.completeProfile) ...[
              const SizedBox(height: 14),
              _buildPhoneField(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDateField() {
    final c = context.colors;
    final d = _birthDate;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: d ?? DateTime(now.year - 14),
          firstDate: DateTime(now.year - 80),
          lastDate: DateTime(now.year - 8, now.month, now.day),
          helpText: 'Date de naissance',
          initialEntryMode: DatePickerEntryMode.calendarOnly,
        );
        if (picked != null) setState(() => _birthDate = picked);
      },
      child: InputDecorator(
        isEmpty: d == null,
        decoration: authInputDecoration(
          context,
          label: 'Date de naissance (facultatif)',
          icon: Icons.cake_outlined,
          helper: 'Elle évite les doublons de comptes dans une même classe.',
        ),
        child: Text(
          d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
          style: TextStyle(color: c.textPrimary, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return PhoneNumberField(
      controller: _phoneCtrl,
      country: _phoneCountry,
      onCountryChanged: (p) => setState(() => _phoneCountry = p),
      helper: 'Servira au paiement Mobile Money (Orange Money, MTN MoMo).',
    );
  }

  Widget _buildGenderField() {
    final c = context.colors;
    return FormField<String>(
      initialValue: _gender,
      validator: (_) => _gender == null ? 'Choisissez une option' : null,
      builder: (field) {
        Widget option(String value, String label, IconData icon) {
          final selected = _gender == value;
          return Expanded(
            child: Material(
              color: selected ? c.accentPrimary.withValues(alpha: 0.14) : c.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: selected ? c.accentPrimary : c.border, width: selected ? 1.6 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  setState(() => _gender = value);
                  field.didChange(value);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: selected ? c.accentPrimary : c.textSecondary),
                      const SizedBox(width: 8),
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: c.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Sexe', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            ),
            Row(
              children: [
                option('feminin', 'Féminin', Icons.female_rounded),
                const SizedBox(width: 12),
                option('masculin', 'Masculin', Icons.male_rounded),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(field.errorText!, style: TextStyle(color: c.accentRose, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  // Étape 2 — compte
  Widget _buildAccountStep() {
    final c = context.colors;
    return Form(
      key: _accountFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepHeader('Vos identifiants', 'Vous vous connecterez avec cet email et ce mot de passe.'),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              style: TextStyle(color: c.textPrimary),
              decoration: authInputDecoration(
                context,
                label: 'Adresse email',
                icon: Icons.alternate_email_rounded,
                hint: 'prenom.nom@gmail.com',
              ),
              validator: emailValidator,
              onChanged: (_) {
                if (_emailAlreadyUsed) setState(() => _emailAlreadyUsed = false);
              },
            ),
            if (_emailAlreadyUsed) ...[
              const SizedBox(height: 12),
              AuthMessageBox.error(
                title: 'Cette adresse a déjà un compte',
                message: 'Connectez-vous avec votre mot de passe actuel. Si vous l\'avez oublié, recevez un lien pour en choisir un nouveau.',
                actions: [
                  TextButton(
                    onPressed: _goToLogin,
                    child: const Text('Me connecter'),
                  ),
                  TextButton(onPressed: _sendPasswordReset, child: const Text('Mot de passe oublié')),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _buildPhoneField(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              style: TextStyle(color: c.textPrimary),
              decoration: authInputDecoration(
                context,
                label: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                helper: 'Au moins 8 caractères, avec des lettres et des chiffres.',
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: c.textSecondary),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: passwordValidator,
            ),
            const SizedBox(height: 10),
            PasswordStrengthMeter(password: _passwordCtrl.text),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              style: TextStyle(color: c.textPrimary),
              decoration: authInputDecoration(context, label: 'Confirmer le mot de passe', icon: Icons.lock_reset_rounded),
              validator: (v) => v != _passwordCtrl.text ? 'Les deux mots de passe ne correspondent pas' : null,
              onFieldSubmitted: (_) => _next(),
            ),
          ],
        ),
      ),
    );
  }

  // Étape 3 — classe
  static const _familyOrder = ['scientifique', 'litteraire', 'artistique'];

  /// Les enfants sont-ils des séries réparties en au moins deux familles ? Si oui, l'élève choisit
  /// d'abord « scientifique » ou « littéraire », puis sa série (demande du porteur).
  bool _needsFamilyChoice(List<StudentAcademicNode> children) {
    if (children.isEmpty || children.any((n) => n.nodeType != 'series')) return false;
    final families = children.map((n) => n.seriesFamily).whereType<String>().toSet();
    return families.length >= 2;
  }

  Widget _buildClassStep(AsyncValue<List<StudentAcademicNode>> childrenAsync) {
    final c = context.colors;
    final children = childrenAsync.valueOrNull ?? const <StudentAcademicNode>[];
    final familyChoice = _needsFamilyChoice(children) && _seriesFamily == null;
    final currentClass = _selectedPath.isEmpty ? null : _selectedPath.last;
    final title = _selectedPath.isEmpty
        ? 'Dans quel pays étudiez-vous ?'
        : familyChoice
            ? 'Quel type de série en ${_shortNodeName(currentClass!.name)} ?'
            : 'Choisissez ${_choiceLabel(children)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(title, 'Les cours, exercices et sujets d\'examens seront ceux de votre classe.'),
        if (_selectedPath.isNotEmpty) ...[
          _buildBreadcrumb(),
          const SizedBox(height: 16),
        ],
        childrenAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => AuthMessageBox.error(
            message: 'Impossible de charger la liste. Vérifiez votre connexion internet.',
            actions: [
              TextButton(
                onPressed: () => ref.invalidate(
                    studentAcademicChildrenProvider(_selectedPath.isEmpty ? null : _selectedPath.last.id)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
          data: (children) {
            if (children.isEmpty) {
              return AuthMessageBox.info(
                message: 'Aucune classe n\'est encore disponible. L\'équipe pq learn les ajoute progressivement.',
              );
            }
            if (familyChoice) {
              final families = _familyOrder.where((f) => children.any((n) => n.seriesFamily == f)).toList();
              return Column(
                children: [
                  for (final f in families) ...[
                    _NodeTile(
                      label: _familyLabel(f),
                      subtitle: _familyExamples(children, f),
                      icon: _familyIcon(f),
                      large: true,
                      onTap: () => setState(() {
                        _errorMessage = null;
                        _seriesFamily = f;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }
            final visible = _seriesFamily == null
                ? children
                : children.where((n) => n.seriesFamily == _seriesFamily || n.seriesFamily == null).toList();
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 440 ? 2 : 1;
                const spacing = 12.0;
                final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final node in visible)
                      SizedBox(
                        width: width,
                        child: _NodeTile(
                          // Filière technique (« IND », « STT ») : l'intitulé complet est plus parlant
                          // que le sigle, qui passe en sous-titre.
                          label: node.nodeType == 'family' && (node.description?.isNotEmpty ?? false)
                              ? node.description!
                              : _leafDisplayLabel(node, _selectedPath),
                          subtitle: node.nodeType == 'family' && (node.description?.isNotEmpty ?? false)
                              ? node.name
                              : node.description,
                          icon: _nodeIcon(node.nodeType),
                          onTap: () => setState(() {
                            _errorMessage = null;
                            _seriesFamily = null;
                            _selectedPath.add(node);
                          }),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Vous pourrez suivre d\'autres classes plus tard depuis votre profil.',
          style: GoogleFonts.inter(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }

  String _familyLabel(String f) => switch (f) {
        'scientifique' => 'Séries scientifiques',
        'litteraire' => 'Séries littéraires',
        _ => 'Séries artistiques',
      };

  IconData _familyIcon(String f) => switch (f) {
        'scientifique' => Icons.science_rounded,
        'litteraire' => Icons.auto_stories_rounded,
        _ => Icons.movie_creation_rounded,
      };

  /// « C, D, E, TI » : aperçu des séries de la famille, avec le nom court de chacune.
  String _familyExamples(List<StudentAcademicNode> children, String f) => children
      .where((n) => n.seriesFamily == f)
      .map((n) => _shortNodeName(n.name))
      .join(', ');

  Widget _buildBreadcrumb() {
    final c = context.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _selectedPath.length; i++) ...[
          ActionChip(
            label: Text(_leafDisplayLabel(_selectedPath[i], _selectedPath.sublist(0, i))),
            labelStyle: GoogleFonts.inter(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600),
            backgroundColor: c.surface,
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            tooltip: 'Revenir à ce niveau',
            onPressed: () => setState(() {
              _seriesFamily = null;
              _selectedPath.removeRange(i, _selectedPath.length);
            }),
          ),
          if (i < _selectedPath.length - 1 || _seriesFamily != null)
            Icon(Icons.chevron_right_rounded, size: 16, color: c.textMuted),
        ],
        if (_seriesFamily != null)
          ActionChip(
            avatar: Icon(_familyIcon(_seriesFamily!), size: 16, color: c.accentPrimary),
            label: Text(_familyLabel(_seriesFamily!)),
            labelStyle: GoogleFonts.inter(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600),
            backgroundColor: c.surface,
            side: BorderSide(color: c.accentPrimary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            tooltip: 'Changer de type de série',
            onPressed: () => setState(() => _seriesFamily = null),
          ),
      ],
    );
  }

  // Récapitulatif
  Widget _buildReviewStep(StudentAcademicNode leaf) {
    final c = context.colors;
    final kind = _accountStepKind;
    final email = kind == _AccountStepKind.completeProfile
        ? (ref.read(studentAuthProvider).sessionEmail ?? '')
        : _emailCtrl.text.trim();
    final classLabel = _leafDisplayLabel(leaf, _selectedPath.sublist(0, _selectedPath.length - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader('Tout est prêt', 'Vérifiez vos informations, puis lancez-vous.'),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    kBrandBlue.withValues(alpha: 0.18),
                    kBrandGreen.withValues(alpha: 0.14),
                  ]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: c.accentPrimary.withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Icon(Icons.school_rounded, color: c.accentPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Votre classe', style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary)),
                          Text(classLabel,
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _seriesFamily = null;
                                _selectedPath.removeLast();
                              }),
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
              ),
              if (kind != _AccountStepKind.none)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    children: [
                      _reviewRow(Icons.person_outline_rounded, 'Élève', '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'),
                      _reviewRow(Icons.alternate_email_rounded, 'Email', email),
                      if (_gender != null)
                        _reviewRow(Icons.wc_rounded, 'Sexe', _gender == 'feminin' ? 'Féminin' : 'Masculin'),
                      if (_normalizedPhone != null) _reviewRow(Icons.phone_iphone_rounded, 'Téléphone', _normalizedPhone!),
                      if (_schoolNameCtrl.text.trim().isNotEmpty)
                        _reviewRow(Icons.apartment_rounded, 'Établissement', _schoolNameCtrl.text.trim()),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: switch (kind) {
            _AccountStepKind.fullSignUp => 'Créer mon compte',
            _AccountStepKind.completeProfile => 'Terminer mon inscription',
            _AccountStepKind.none => 'Ajouter cette classe',
          },
          isLoading: _isSubmitting,
          onPressed: () => _submitFinal(leaf),
        ),
        if (kind == _AccountStepKind.fullSignUp) ...[
          const SizedBox(height: 12),
          Text(
            'Un email de confirmation vous sera envoyé à cette adresse.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: c.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // Après l'envoi de l'email de confirmation
  Widget _buildEmailSentView(String email) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: c.accentPrimary.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(Icons.mark_email_unread_rounded, size: 44, color: c.accentPrimary),
          ),
        ),
        const SizedBox(height: 24),
        Text('Vérifiez votre boîte mail',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: c.textSecondary),
            children: [
              const TextSpan(text: 'Nous avons envoyé un lien de confirmation à\n'),
              TextSpan(text: email, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              const TextSpan(text: '.\nCliquez dessus pour activer votre compte : votre classe sera enregistrée automatiquement.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AuthMessageBox.info(
          title: 'Rien reçu ?',
          message: 'Regardez dans les dossiers « Spam » ou « Promotions ». L\'email peut mettre une à deux minutes à arriver.',
        ),
        if (_infoMessage != null) ...[
          const SizedBox(height: 12),
          AuthMessageBox.success(message: _infoMessage!),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          AuthMessageBox.error(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'J\'ai confirmé, me connecter',
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isSubmitting ? null : _resendEmail,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Renvoyer l\'email', style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => setState(() {
            _emailSentTo = null;
            _errorMessage = null;
            _infoMessage = null;
            _stepIndex = _steps.indexOf(_Step.account);
          }),
          child: Text('Modifier l\'adresse email', style: GoogleFonts.inter(color: c.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildAlreadyHaveAccount() {
    final c = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Déjà un compte ?', style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary)),
        TextButton(
          onPressed: _goToLogin,
          child: Text('Se connecter',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.accentPrimary)),
        ),
      ],
    );
  }

  // ─── Libellés ──────────────────────────────────────────────────────────────

  String _choiceLabel(List<StudentAcademicNode>? children) {
    final type = (children == null || children.isEmpty) ? null : children.first.nodeType;
    return switch (type) {
      'section' => 'votre section',
      'education_type' => 'votre type d\'enseignement',
      'class' => 'votre classe',
      'series' => 'votre série',
      'specialty' => 'votre spécialité',
      'cycle' => 'votre cycle',
      _ => 'votre niveau',
    };
  }

  IconData _nodeIcon(String type) => switch (type) {
        'country' => Icons.public_rounded,
        'section' => Icons.translate_rounded,
        'education_type' => Icons.account_balance_rounded,
        'class' => Icons.class_rounded,
        'series' => Icons.workspaces_outline,
        'specialty' => Icons.precision_manufacturing_rounded,
        _ => Icons.layers_rounded,
      };

  /// Une série ou spécialité seule (« A », « ESCOM ») n'a pas de sens hors de sa classe : on affiche
  /// « 2nde A » ou « Première ESCOM ». On remonte le chemin jusqu'à la classe la plus proche, car
  /// une spécialité technique est parfois séparée de sa classe par plusieurs niveaux.
  String _leafDisplayLabel(StudentAcademicNode leaf, List<StudentAcademicNode> path) {
    if (leaf.nodeType != 'series' && leaf.nodeType != 'specialty') return leaf.name;
    StudentAcademicNode? ancestorClass;
    for (final n in path.reversed) {
      if (n.nodeType == 'class') {
        ancestorClass = n;
        break;
      }
    }
    if (ancestorClass == null) return leaf.name;
    return '${_shortNodeName(ancestorClass.name)} ${_shortNodeName(leaf.name)}';
  }

  String _shortNodeName(String name) => name
      .replaceFirst(RegExp(r'^Classe de\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Série\s+', caseSensitive: false), '')
      .trim();
}

class _NodeTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool large;

  const _NodeTile({required this.label, required this.icon, required this.onTap, this.subtitle, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: large ? 18 : 14),
          child: Row(
            children: [
              Container(
                width: large ? 46 : 38,
                height: large ? 46 : 38,
                decoration: BoxDecoration(
                  color: c.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: c.accentPrimary, size: large ? 24 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontSize: large ? 16 : 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12.5, height: 1.35, color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
