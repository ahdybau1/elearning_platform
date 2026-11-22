import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/phone_countries.dart';
import '../../../core/theme/student_theme.dart';

/// Composants partagés par les écrans d'authentification (connexion, inscription, mot de passe).
/// Objectif : une seule apparence cohérente au lieu de champs et boutons redessinés à la main dans
/// chaque écran.

/// Couleurs du logo pq learn (bleu → vert), utilisées pour le panneau de marque et les accents.
const Color kBrandBlue = Color(0xFF1F5EFF);
const Color kBrandGreen = Color(0xFF12B04F);

/// Fond commun des écrans d'authentification.
/// - Téléphone (< 600 px) : plein écran, contenu qui défile, bouton principal fixé en bas
///   ([bottomBar]) pour qu'il reste toujours accessible au pouce, au-dessus du clavier.
/// - Tablette : carte centrée.
/// - Grand écran (≥ 960 px) : panneau de marque à gauche, formulaire à droite.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final Widget? topBar;
  final Widget? bottomBar;
  final double maxWidth;

  const AuthScaffold({super.key, required this.child, this.topBar, this.bottomBar, this.maxWidth = 460});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final phone = constraints.maxWidth < 600;
          final form = SafeArea(
            bottom: !phone || bottomBar == null,
            child: Column(
              children: [
                if (topBar != null) topBar!,
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(phone ? 20 : 40, phone ? 12 : 24, phone ? 20 : 40, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            child,
                            if (!phone && bottomBar != null) ...[const SizedBox(height: 28), bottomBar!],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (phone && bottomBar != null)
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), child: bottomBar!),
                    ),
                  ),
              ],
            ),
          );
          if (!wide) return form;
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: form),
            ],
          );
        },
      ),
    );
  }
}

/// Barre de progression en segments (une par étape), plus lisible qu'une barre continue.
class StepProgress extends StatelessWidget {
  final int current; // index de l'étape courante (0-based)
  final int total;
  const StepProgress({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i <= current ? c.accentPrimary : c.border,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F5C), Color(0xFF0E3B8C), Color(0xFF0B6B45)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Image.asset('assets/branding/logo.png', width: 56, height: 56),
          ),
          const Spacer(),
          Text(
            'Réviser ton programme,\nà ton rythme.',
            style: GoogleFonts.outfit(fontSize: 36, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Cours, exercices corrigés et sujets d\'examens alignés sur le programme officiel du Cameroun.',
            style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: Colors.white.withValues(alpha: 0.82)),
          ),
          const SizedBox(height: 32),
          const _BrandPoint(icon: Icons.menu_book_rounded, text: 'Leçons structurées, de la 6e à la Terminale'),
          const _BrandPoint(icon: Icons.task_alt_rounded, text: 'Exercices avec corrigés pas à pas'),
          const _BrandPoint(icon: Icons.school_rounded, text: 'Annales BEPC, Probatoire et Baccalauréat'),
          const Spacer(),
          Text(
            '© pq learn',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BrandPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class AuthLogo extends StatelessWidget {
  final double size;
  const AuthLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset('assets/branding/logo.png', width: size, height: size),
    );
  }
}

InputDecoration authInputDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
  String? hint,
  String? helper,
  String? prefixText,
  Widget? suffix,
}) {
  final c = context.colors;
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixText: prefixText,
    prefixStyle: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
    labelStyle: TextStyle(color: c.textSecondary),
    floatingLabelStyle: TextStyle(color: c.accentPrimary, fontWeight: FontWeight.w600),
    hintStyle: TextStyle(color: c.textMuted),
    helperStyle: TextStyle(color: c.textMuted, fontSize: 12),
    prefixIcon: icon == null ? null : Icon(icon, color: c.textSecondary, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: c.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(c.border),
    enabledBorder: border(c.border),
    focusedBorder: border(c.accentPrimary, 1.6),
    errorBorder: border(c.accentRose),
    focusedErrorBorder: border(c.accentRose, 1.6),
  );
}

String? requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

String? emailValidator(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return 'Champ obligatoire';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$').hasMatch(value);
  return ok ? null : 'Adresse email invalide (ex. prenom.nom@gmail.com)';
}

/// Au moins 8 caractères, avec au moins une lettre et un chiffre.
String? passwordValidator(String? v) {
  final value = v ?? '';
  if (value.length < 8) return 'Au moins 8 caractères';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return 'Mélangez des lettres et des chiffres';
  }
  return null;
}

/// Numéro camerounais facultatif : 9 chiffres commençant par 6 (le +237 est affiché devant).
String? cameroonPhoneValidator(String? v) {
  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.length != 9 || !digits.startsWith('6')) return '9 chiffres commençant par 6 (ex. 6 77 12 34 56)';
  return null;
}

/// Jauge de robustesse du mot de passe (indicative, la règle bloquante est [passwordValidator]).
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  int get _score {
    var s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12) s++;
    if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final score = _score;
    final (label, color) = switch (score) {
      0 || 1 => ('Faible', c.accentRose),
      2 => ('Moyen', c.accentAmber),
      3 => ('Bon', c.accentEmerald),
      _ => ('Excellent', c.accentEmerald),
    };
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? color : c.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

enum _AuthMessageKind { error, info, success }

/// Encadré de message (erreur, information, succès) avec actions facultatives.
class AuthMessageBox extends StatelessWidget {
  final String message;
  final String? title;
  final List<Widget> actions;
  final _AuthMessageKind _kind;

  const AuthMessageBox.error({super.key, required this.message, this.title, this.actions = const []})
      : _kind = _AuthMessageKind.error;
  const AuthMessageBox.info({super.key, required this.message, this.title, this.actions = const []})
      : _kind = _AuthMessageKind.info;
  const AuthMessageBox.success({super.key, required this.message, this.title, this.actions = const []})
      : _kind = _AuthMessageKind.success;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon) = switch (_kind) {
      _AuthMessageKind.error => (c.accentRose, Icons.error_outline_rounded),
      _AuthMessageKind.info => (c.accentPrimary, Icons.info_outline_rounded),
      _AuthMessageKind.success => (c.accentEmerald, Icons.check_circle_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    const SizedBox(height: 4),
                  ],
                  Text(message, style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: c.textSecondary)),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: actions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.isLoading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.accentPrimary,
          foregroundColor: Colors.black,
          disabledBackgroundColor: c.accentPrimary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
                ],
              ),
      ),
    );
  }
}

/// Bouton « Continuer avec Google ». L'icône est un G générique de Material Icons : pour respecter
/// la charte Google, remplacer par le logo officiel téléchargé depuis les ressources de marque
/// Google (Sign in with Google branding guidelines) dans assets/branding/.
class GoogleAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const GoogleAuthButton({super.key, required this.onPressed, this.isLoading = false, this.label = 'Continuer avec Google'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.card,
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.textPrimary))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.g_mobiledata_rounded, color: kBrandBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  final String label;
  const OrDivider({super.key, this.label = 'ou'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: c.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: c.textMuted)),
        ),
        Expanded(child: Divider(color: c.border)),
      ],
    );
  }
}


// ─── Sexe ────────────────────────────────────────────────────────────────────

/// Choix du sexe en deux grandes cartes (plus simple au doigt qu'une liste déroulante).
class GenderField extends FormField<String> {
  GenderField({super.key, super.initialValue, required ValueChanged<String> onChanged})
      : super(
          validator: (v) => v == null ? 'Choisissez une option' : null,
          builder: (state) {
            final context = state.context;
            final c = context.colors;
            Widget option(String value, String label, IconData icon) {
              final selected = state.value == value;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      state.didChange(value);
                      onChanged(value);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 56,
                      decoration: BoxDecoration(
                        color: selected ? c.accentPrimary.withValues(alpha: 0.14) : c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? c.accentPrimary : c.border, width: selected ? 1.6 : 1),
                      ),
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
                Row(children: [
                  option('masculin', 'Masculin', Icons.male_rounded),
                  const SizedBox(width: 12),
                  option('feminin', 'Féminin', Icons.female_rounded),
                ]),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 6),
                    child: Text(state.errorText!, style: TextStyle(color: c.accentRose, fontSize: 12)),
                  ),
              ],
            );
          },
        );
}

// ─── Téléphone avec pays ─────────────────────────────────────────────────────

/// Numéro national valide pour le pays choisi. Cameroun : 9 chiffres commençant par 6 ou 2.
/// Autres pays : de 6 à 14 chiffres (norme E.164, indicatif non compris).
String? phoneValidatorFor(PhoneCountry country, String? value, {bool required = false}) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return required ? 'Champ obligatoire' : null;
  if (country.code == 'CM') {
    if (digits.length != 9 || !(digits.startsWith('6') || digits.startsWith('2'))) {
      return '9 chiffres commençant par 6 ou 2 (ex. 6 77 12 34 56)';
    }
    return null;
  }
  if (digits.length < 6 || digits.length > 14) return 'Numéro invalide pour ${country.name}';
  return null;
}

class CountryFlag extends StatelessWidget {
  final PhoneCountry country;
  final double height;
  const CountryFlag({super.key, required this.country, this.height = 16});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        country.flagUrl,
        height: height,
        width: height * 1.4,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => SizedBox(
          height: height,
          width: height * 1.4,
          child: Center(child: Text(country.code, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

/// Champ téléphone : bouton pays (drapeau + indicatif) puis numéro national.
class PhoneCountryField extends StatelessWidget {
  final TextEditingController controller;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String label;
  final String? helper;
  final bool required;

  const PhoneCountryField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.label = 'Téléphone',
    this.helper,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      style: TextStyle(color: c.textPrimary),
      decoration: authInputDecoration(
        context,
        label: label,
        hint: country.code == 'CM' ? '6 77 12 34 56' : null,
        helper: helper,
      ).copyWith(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6, right: 4),
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: c.textPrimary,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () async {
              final picked = await showPhoneCountryPicker(context, selected: country);
              if (picked != null) onCountryChanged(picked);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountryFlag(country: country),
                const SizedBox(width: 6),
                Text(country.dialCode, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_drop_down_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
      validator: (v) => phoneValidatorFor(country, v, required: required),
    );
  }
}

/// Fenêtre de choix du pays, avec recherche (même principe que Voie Vérité Vie).
Future<PhoneCountry?> showPhoneCountryPicker(BuildContext context, {PhoneCountry? selected}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CountryPickerSheet(selected: selected),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final PhoneCountry? selected;
  const _CountryPickerSheet({this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _all = phoneCountriesSorted();
  String _query = '';

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _normalize(_query.trim());
    final list = q.isEmpty
        ? _all
        : _all
            .where((x) => _normalize(x.name).contains(q) || x.dialCode.contains(q) || x.code.toLowerCase() == q)
            .toList();
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Pays de votre numéro',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              style: TextStyle(color: c.textPrimary),
              decoration: authInputDecoration(context, label: 'Rechercher un pays ou un indicatif', icon: Icons.search_rounded),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('Aucun pays trouvé', style: TextStyle(color: c.textMuted)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final country = list[i];
                      final isSelected = country.code == widget.selected?.code;
                      return ListTile(
                        leading: CountryFlag(country: country, height: 20),
                        title: Text(country.name, style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(country.dialCode, style: GoogleFonts.inter(color: c.textSecondary, fontSize: 14)),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_rounded, color: c.accentPrimary, size: 20),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.pop(context, country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
