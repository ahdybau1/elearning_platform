import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Rend un texte mêlant prose et formules LaTeX délimitées par `$...$` (en ligne) ou `$$...$$`
/// (bloc) — le format réellement produit par le pipeline IA du projet : le prompt d'OCRAgent
/// (`supabase/functions/ai-exam-paper-processing/index.ts`) demande explicitement « LaTeX si
/// formules ($...$) », et la génération de cours/exercices écrit des formules dans `latex_formulas`.
///
/// Constat qui motive ce widget (audit du 2026-09-06) : avant lui, AUCUN moteur de rendu
/// mathématique n'existait dans le projet — ces formules s'affichaient littéralement `$x^2+2x$` à
/// l'écran comme du texte brut, dans les leçons, les exercices et l'écran de révision des sujets.
///
/// `Text.rich` + `WidgetSpan` (et non un `Wrap`) pour que le texte continue de s'aligner et de
/// revenir à la ligne mot par mot autour d'une formule en ligne. Une formule LaTeX invalide n'est
/// jamais une exception : `onErrorFallback` réaffiche la source brute — un contenu généré par IA
/// n'est pas garanti syntaxiquement correct, il ne doit jamais casser l'écran.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.mathStyle, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextStyle? mathStyle;
  final TextAlign? textAlign;

  static final RegExp _pattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

  /// Vrai si le texte contient au moins un segment LaTeX — permet à un appelant de n'afficher un
  /// aperçu rendu que quand il y a réellement quelque chose à rendre.
  static bool containsMath(String text) => _pattern.hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    var last = 0;

    for (final match in _pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final isDisplay = match.group(1) != null;
      final formula = (isDisplay ? match.group(1) : match.group(2)) ?? '';
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          formula,
          textStyle: mathStyle ?? effectiveStyle,
          onErrorFallback: (_) => Text(
            isDisplay ? '\$\$$formula\$\$' : '\$$formula\$',
            style: effectiveStyle,
          ),
        ),
      ));
      last = match.end;
    }

    if (spans.isEmpty) {
      return Text(text, style: effectiveStyle, textAlign: textAlign);
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return Text.rich(TextSpan(style: effectiveStyle, children: spans), textAlign: textAlign);
  }
}
