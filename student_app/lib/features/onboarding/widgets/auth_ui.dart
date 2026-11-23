import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/student_theme.dart';

/// Composants partagés par les écrans d'authentification (connexion, inscription, mot de passe).
/// Objectif : une seule apparence cohérente au lieu de champs et boutons redessinés à la main dans
/// chaque écran.

/// Couleurs du logo pq learn (bleu → vert), utilisées pour le panneau de marque et les accents.
const Color kBrandBlue = Color(0xFF1F5EFF);
const Color kBrandGreen = Color(0xFF12B04F);

/// Fond commun : carte centrée sur mobile, panneau de marque à gauche sur grand écran (≥ 960 px).
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final Widget? topBar;
  /// Barre d'action fixée en bas (bouton principal) : toujours visible au pouce sur téléphone,
  /// même quand le formulaire défile.
  final Widget? bottomBar;
  final double maxWidth;

  const AuthScaffold({super.key, required this.child, this.topBar, this.bottomBar, this.maxWidth = 460});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final form = SafeArea(
            child: Column(
              children: [
                if (topBar != null) topBar!,
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: wide ? 24 : 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: child,
                      ),
                    ),
                  ),
                ),
                if (bottomBar != null)
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      border: Border(top: BorderSide(color: context.colors.border.withValues(alpha: 0.6))),
                    ),
                    padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 12, wide ? 48 : 20, 12),
                    child: Center(
                      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: bottomBar),
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
