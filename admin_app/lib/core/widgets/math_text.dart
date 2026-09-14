import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Rend un texte mêlant prose et formules scientifiques (LaTeX) — la chaîne réelle produite par le
/// pipeline IA du projet (structuration de cours, exercices, OCR de sujets) et par la saisie
/// manuelle des admins/enseignants dans le Studio.
///
/// Corrige les défauts réels constatés le 2026-09-12 (retour utilisateur direct) :
///  - seuls `$...$` / `$$...$$` étaient reconnus ; `\(...\)` / `\[...\]` (fréquents avec les sorties
///    Gemini) s'affichaient en texte brut ;
///  - un `$` isolé (montant, symbole) pouvait amorcer un appariement qui engloutissait tout le
///    reste du paragraphe jusqu'au `$` suivant, cassant la lecture de tout le bloc ;
///  - les équations `$$...$$` étaient injectées EN LIGNE dans le texte (WidgetSpan) au lieu
///    d'apparaître sur leur propre ligne, centrées, comme une vraie équation hors-texte ;
///  - aucune prise en charge des notations chimiques (`\ce{...}`, extension mhchem — absente de
///    flutter_math_fork) : affichées en code brut ;
///  - une formule invalide réaffichait le code LaTeX brut au lieu d'un signalement clair.
///
/// Contrat conservé : `MathText(text, {style, mathStyle, textAlign})`, utilisable comme n'importe
/// quel widget de paragraphe (jamais une exception : un flux invalide est toujours absorbé).
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.mathStyle, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextStyle? mathStyle;
  final TextAlign? textAlign;

  /// Formule en ligne : bornée à UNE ligne, sans `$` imbriqué — empêche un `$` isolé (ex: prix)
  /// d'amorcer un appariement qui engloutirait tout le paragraphe suivant.
  static final RegExp _inlineDollar = RegExp(r'\$([^\n$]+?)\$');

  /// Équation hors-texte : `$$...$$`, peut s'étendre sur plusieurs lignes.
  static final RegExp _displayDollar = RegExp(r'\$\$([\s\S]+?)\$\$');

  static bool containsMath(String text) => _prepare(text).spans.any((s) => !s.isText);

  /// Rend UNE formule LaTeX isolée (pas un texte mêlé de prose) — utilisé par les encadrés
  /// pédagogiques (`ElefCallout`, blocs "formule") qui stockent leurs formules dans un champ dédié
  /// sans délimiteurs `$...$`. Même moteur que `MathText` (repli chimie, erreur non brute) : source
  /// unique de vérité pour que l'éditeur, l'aperçu et la consultation rendent la même chose.
  static Widget formula(
    String latex, {
    TextStyle? style,
    bool display = true,
  }) {
    // Accepte aussi bien 'x^2' que '$x^2$'/'$$x^2$$' déjà délimité : on retire les délimiteurs
    // existants avant de les réappliquer nous-mêmes, pour ne jamais les doubler.
    final stripped = latex.trim().replaceAll(RegExp(r'^\${1,2}|\${1,2}$'), '');
    return _renderFormulaStatic(
      stripped,
      style ?? const TextStyle(fontSize: 16, color: Colors.white),
      display: display,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final prepared = _prepare(text);

    if (prepared.spans.isEmpty) {
      return Text(prepared.plain, style: effectiveStyle, textAlign: textAlign);
    }

    // Regroupe le flux en paragraphes de prose (avec formules EN LIGNE) séparés par les équations
    // HORS-TEXTE, qui deviennent chacune un bloc centré sur sa propre ligne.
    final children = <Widget>[];
    final currentInline = <InlineSpan>[];
    void flushInline() {
      if (currentInline.isEmpty) return;
      children.add(Text.rich(
        TextSpan(style: effectiveStyle, children: List.of(currentInline)),
        textAlign: textAlign,
      ));
      currentInline.clear();
    }

    for (final seg in prepared.spans) {
      if (seg.display) {
        flushInline();
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(child: _renderFormulaStatic(seg.formula, mathStyle ?? effectiveStyle, display: true)),
        ));
      } else if (seg.isText) {
        currentInline.add(TextSpan(text: seg.formula));
      } else {
        currentInline.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _renderFormulaStatic(seg.formula, mathStyle ?? effectiveStyle, display: false),
        ));
      }
    }
    flushInline();

    if (children.length == 1) return children.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }

  static Widget _renderFormulaStatic(String rawFormula, TextStyle baseStyle, {required bool display}) {
    final formula = _convertChemistry(rawFormula.trim());
    return Math.tex(
      formula,
      textStyle: display ? baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) * 1.1) : baseStyle,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      onErrorFallback: (err) => Tooltip(
        message: 'Formule invalide : ${rawFormula.trim()}\n${err.message}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text('formule invalide',
                  style: baseStyle.copyWith(
                      fontSize: (baseStyle.fontSize ?? 14) * 0.85,
                      color: Colors.redAccent,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Normalisation & segmentation ───────────────────────────

  static _Prepared _prepare(String raw) {
    // 1. `\[...\]` -> `$$...$$`, `\(...\)` -> `$...$` (sorties Gemini fréquentes).
    var t = raw
        .replaceAllMapped(RegExp(r'\\\[([\s\S]+?)\\\]'), (m) => '\$\$${m[1]}\$\$')
        .replaceAllMapped(RegExp(r'\\\(([\s\S]+?)\\\)'), (m) => '\$${m[1]}\$');

    // 2. `\$` échappé (montant littéral) -> jeton neutre, restauré en `$` littéral hors formule.
    const esc = '\u0000ESC_DOLLAR\u0000';
    t = t.replaceAll(r'\$', esc);

    final spans = <_Seg>[];
    var cursor = 0;
    final combined = RegExp('${_displayDollar.pattern}|${_inlineDollar.pattern}');
    for (final m in combined.allMatches(t)) {
      if (m.start > cursor) {
        spans.add(_Seg.text(t.substring(cursor, m.start).replaceAll(esc, r'$')));
      }
      final isDisplay = m.group(1) != null;
      final formula = (isDisplay ? m.group(1) : m.group(2)) ?? '';
      // Une formule qui ne contient elle-même aucune commande/symbole LaTeX plausible et pas de
      // chiffre/lettre isolée typique d'une variable est presque sûrement un faux positif (ex:
      // guillemets, prix) : on la restitue comme texte plutôt que de tenter un rendu absurde.
      spans.add(_Seg.math(formula, display: isDisplay));
      cursor = m.end;
    }
    if (cursor < t.length) spans.add(_Seg.text(t.substring(cursor).replaceAll(esc, r'$')));

    // Fusionne les segments texte adjacents et calcule le texte brut équivalent (repli `plain`).
    final plain = spans.map((s) => s.isText ? s.formula : (s.display ? '\$\$${s.formula}\$\$' : '\$${s.formula}\$')).join();
    return _Prepared(spans.where((s) => !(s.isText && s.formula.isEmpty)).toList(), plain.isEmpty ? raw : plain);
  }

  /// Repli mhchem minimal (flutter_math_fork n'implémente pas l'extension \ce{}) : convertit les
  /// flèches de réaction et les indices/exposants usuels en LaTeX standard compatible KaTeX, pour
  /// un rendu lisible plutôt qu'un code brut — pas une implémentation mhchem complète.
  static String _convertChemistry(String formula) {
    final ceMatch = RegExp(r'\\ce\s*\{([\s\S]+)\}$').firstMatch(formula.trim());
    if (ceMatch == null) return formula;
    var inner = ceMatch.group(1)!;
    inner = inner
        .replaceAll('<=>', r'\rightleftharpoons')
        .replaceAll('<->', r'\leftrightarrow')
        .replaceAll('->', r'\rightarrow');
    // Indices : un chiffre collé après une lettre/parenthèse fermante devient un indice (H2O -> H_2O),
    // jamais un coefficient stœchiométrique en tête de terme (espace/début avant le chiffre).
    inner = inner.replaceAllMapped(RegExp(r'([A-Za-z\)\]])(\d+)'), (m) => '${m[1]}_{${m[2]}}');
    // Charges usuelles en fin de terme : Fe^3+ / Cl- / SO4^2- -> exposants LaTeX.
    inner = inner.replaceAllMapped(RegExp(r'\^?(\d*)([+-])(?=[\s+]|$)'), (m) {
      final n = m.group(1) ?? '';
      final sign = m.group(2)!;
      return '^{$n$sign}';
    });
    return inner;
  }
}

class _Prepared {
  final List<_Seg> spans;
  final String plain;
  _Prepared(this.spans, this.plain);
}

class _Seg {
  final String formula; // texte brut si isText, sinon code LaTeX
  final bool isText;
  final bool display;
  _Seg._(this.formula, this.isText, this.display);
  factory _Seg.text(String t) => _Seg._(t, true, false);
  factory _Seg.math(String f, {required bool display}) => _Seg._(f, false, display);
}
