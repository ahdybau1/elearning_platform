import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import 'latex_to_unicode_converter.dart';
import 'mathjax_bridge.dart';
import '../theme/student_theme.dart';

/// Moteurs de rendu mathématique supportés (Cahier IA Zéro-Coût §5 & Cahier Technique §2)
enum MathRendererEngine {
  katex,
  mathjax,
}

/// Gestionnaire global du moteur de rendu mathématique
class MathRendererSettings {
  // Rendu natif (flutter_math) par défaut partout, y compris sur le web : le rendu MathJax passe par
  // une iframe de taille fixe par formule, chargée depuis un CDN — formules coupées, lentes, ou
  // absentes hors connexion. MathJax ne sert plus que de secours quand flutter_math échoue.
  static final ValueNotifier<MathRendererEngine> currentEngine =
      ValueNotifier<MathRendererEngine>(MathRendererEngine.katex);

  static void toggleEngine() {
    currentEngine.value = currentEngine.value == MathRendererEngine.katex
        ? MathRendererEngine.mathjax
        : MathRendererEngine.katex;
  }

  static void setEngine(MathRendererEngine engine) {
    currentEngine.value = engine;
  }
}

/// Composant de rendu mathématique vectoriel haute-définition.
class MathFormulaView extends StatelessWidget {
  final String formulaLatex;
  final double fontSize;
  final Color? textColor;
  final bool isDisplayMode;
  final bool showCopyButton;
  final bool showEngineToggle;
  final String? label;

  const MathFormulaView({
    super.key,
    required this.formulaLatex,
    this.fontSize = 17.5,
    this.textColor,
    this.isDisplayMode = true,
    this.showCopyButton = true,
    this.showEngineToggle = false,
    this.label,
  });

  /// Nettoie et prépare la formule pour le moteur KaTeX / MathJax
  String _sanitizeLatex(String input) {
    var sanitized = input.trim();
    if (sanitized.startsWith(r'$$') && sanitized.endsWith(r'$$') && sanitized.length > 4) {
      sanitized = sanitized.substring(2, sanitized.length - 2).trim();
    } else if (sanitized.startsWith(r'$') && sanitized.endsWith(r'$') && sanitized.length > 2) {
      sanitized = sanitized.substring(1, sanitized.length - 1).trim();
    }
    return sanitized;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final effectiveTextColor = textColor ?? c.textPrimary;
    final sanitizedFormula = InlineLatexText.normalizeLatexSource(_sanitizeLatex(formulaLatex));
    final showHeader = label != null || showCopyButton || showEngineToggle;

    // Si la formule comporte un environnement LaTeX complet (\begin{cases}, \begin{matrix}, \begin{aligned}, etc.),
    // elle constitue un bloc mathématique unitaire : ne JAMAIS la découper par \\ ni supprimer les alignements &.
    final bool hasEnvironment = sanitizedFormula.contains(r'\begin{');
    final List<String> lines = hasEnvironment
        ? [sanitizedFormula]
        : (sanitizedFormula.contains(r'\\')
            ? sanitizedFormula
                .split(r'\\')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList()
            : [sanitizedFormula]);

    return ValueListenableBuilder<MathRendererEngine>(
      valueListenable: MathRendererSettings.currentEngine,
      builder: (context, engine, _) {
        final isMathJax = engine == MathRendererEngine.mathjax;
        final themeColor = isMathJax ? const Color(0xFF10B981) : AppColors.primaryCyan;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête (étiquette, moteur, copier) seulement s'il a quelque chose à montrer.
              if (showHeader) Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor.withAlpha(30),
                            borderRadius: AppRadius.radiusSmall,
                            border: Border.all(color: themeColor.withAlpha(100)),
                          ),
                          child: Text(
                            label ?? 'FORMULE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (showEngineToggle)
                          InkWell(
                            onTap: () => MathRendererSettings.toggleEngine(),
                            borderRadius: AppRadius.radiusSmall,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(15),
                                borderRadius: AppRadius.radiusSmall,
                                border: Border.all(color: Colors.white.withAlpha(40)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 11, color: themeColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    isMathJax ? 'Rendu standard' : 'Rendu vectoriel',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showCopyButton)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: LatexToUnicodeConverter.convert(formulaLatex)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Formule copiée dans le presse-papier.'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: AppRadius.radiusSmall,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: c.textMuted),
                            const SizedBox(width: 4),
                            Text('Copier', style: TextStyle(color: c.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (showHeader) const SizedBox(height: 10),

              // Zone de rendu de la formule avec défilement horizontal fluide
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines.map((line) {
                    // Nettoyer les alignements & seulement hors environnement unitaire
                    final cleanLine = hasEnvironment ? line : line.replaceAll('&', ' ').trim();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: isMathJax
                          ? MathJaxSvgView(
                              latex: cleanLine,
                              isDisplay: isDisplayMode,
                              color: effectiveTextColor,
                              fontSize: fontSize,
                            )
                          : Math.tex(
                              cleanLine,
                              mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
                              textStyle: TextStyle(
                                fontSize: fontSize,
                                color: effectiveTextColor,
                              ),
                              onErrorFallback: (err) {
                                // Sur le web, MathJax sait rendre ce que flutter_math refuse ; ailleurs,
                                // repli Unicode lisible, jamais de code TeX brut montré à l'élève.
                                if (kIsWeb) {
                                  return MathJaxSvgView(
                                    latex: cleanLine,
                                    isDisplay: isDisplayMode,
                                    color: effectiveTextColor,
                                    fontSize: fontSize,
                                  );
                                }
                                final safeMathText = LatexToUnicodeConverter.convert(cleanLine);
                                return SelectableText(
                                  safeMathText,
                                  style: GoogleFonts.inter(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600,
                                    color: effectiveTextColor,
                                  ),
                                );
                              },
                            ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget capable de parser du texte mixte (texte normal + fragments LaTeX $...$ ou $$...$$).
///
/// Idéal pour les énoncés d'exercices, les explications de corrigés, les messages du tuteur et les options de QCM
/// sans forcer tout le texte en bloc mathématique et sans JAMAIS laisser fuiter de code brut.
class InlineLatexText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? mathColor;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const InlineLatexText(
    this.text, {
    super.key,
    this.style,
    this.mathColor,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  // $$…$$ puis $…$ sur une seule ligne (un $ isolé, ex. un prix, ne doit pas avaler la suite).
  static final RegExp _mathPattern = RegExp(r'\$\$([\s\S]+?)\$\$|\$([^\$\n]+?)\$');

  /// Ramène les délimiteurs LaTeX usuels à $…$ / $$…$$ et corrige les écritures fréquentes que
  /// flutter_math ne comprend pas (virgule décimale, \dfrac, espaces insécables, ≤ ≥ en clair…).
  static String normalizeLatexSource(String input) {
    var s = input;
    s = s.replaceAllMapped(RegExp(r'\\\[([\s\S]+?)\\\]'), (m) => '\$\$${m.group(1)!.trim()}\$\$');
    s = s.replaceAllMapped(RegExp(r'\\\(([\s\S]+?)\\\)'), (m) => '\$${m.group(1)!.trim()}\$');
    s = s
        .replaceAll(r'\dfrac', r'\frac')
        .replaceAll(r'\tfrac', r'\frac')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ');
    return s;
  }

  /// Rétro-compatibilité : texte sans aucun $ mais avec des commandes LaTeX évidentes (\frac{…}{…},
  /// \sqrt{…}, x^{2}, x_1, \Delta…) — seules ces commandes sont encadrées, jamais les mots autour.
  /// L'ancienne version encadrait des segments entiers (« f(x) = 2x + 1 est croissante ») et les
  /// rendait en italique mathématique collé, illisible.
  static String autoDelimitMath(String input) {
    final normalized = normalizeLatexSource(input);
    if (normalized.isEmpty || normalized.contains(r'$')) return normalized;
    return normalized.replaceAllMapped(_latexTokenPattern, (m) => '\$${m.group(0)}\$');
  }

  static final RegExp _latexTokenPattern = RegExp(
    // Commandes avec arguments entre accolades (éventuellement imbriquées sur un niveau) : \frac{a}{b},
    // \sqrt{x}, \vec{u}, \overline{AB}, \text{…}
    r'\\[a-zA-Z]+(?:\[[^\]]*\])?(?:\{(?:[^{}]|\{[^{}]*\})*\})+'
    // Commandes simples : \Delta, \infty, \pi, \times, \leq, \mathbb R…
    r'|\\(?:Delta|delta|alpha|beta|gamma|lambda|mu|pi|theta|omega|Omega|sigma|varepsilon|epsilon|infty|times|cdot|div|pm|mp|leq|geq|le|ge|neq|approx|equiv|in|notin|subset|cup|cap|forall|exists|Rightarrow|Leftrightarrow|implies|iff|to|mapsto|ldots|cdots|circ|degree|parallel|perp|angle)\b'
    // Puissances et indices explicites : x^2, x^{n+1}, e^{-x}, u_n, x_{1}, 10^{-3}
    r'|[A-Za-z0-9)\]]+(?:\^\{[^}]+\}|\^-?[A-Za-z0-9]+|_\{[^}]+\}|_[A-Za-z0-9]+)+',
  );

  /// Vrai si la chaîne entière est une formule (pas une phrase) : on peut alors la rendre d'un bloc.
  static bool _looksLikePureFormula(String s) {
    final t = s.trim();
    if (t.isEmpty || t.length > 160) return false;
    if (!(t.contains(r'\') || t.contains('^') || t.contains('_'))) return false;
    // Mots de 3 lettres ou plus en dehors des commandes LaTeX → c'est une phrase.
    final withoutCommands = t.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ');
    return !RegExp(r'[A-Za-zÀ-ÿ]{3,}').hasMatch(withoutCommands);
  }

  /// Conservé pour les appels existants : indique si une chaîne contient des mathématiques.
  static bool containsMath(String s) =>
      s.contains(r'$') || s.contains(r'\(') || s.contains(r'\[') || _latexTokenPattern.hasMatch(s);

  /// Découpe un fragment de texte brut en spans stylisés selon la syntaxe Markdown
  /// (**gras**, *italique*, ***gras italique***, `code`, ~~barré~~)
  static List<InlineSpan> parseMarkdownSpans(String text, TextStyle baseStyle) {
    if (text.isEmpty) return const [];

    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*\*(.*?)\*\*\*)|' // 1: ***bold italic*** (group 2)
      r'(\*\*(.*?)\*\*)|'     // 3: **bold** (group 4)
      r'(__([^_]+)__)|'       // 5: __bold__ (group 6)
      r'(\*(.*?)\*)|'         // 7: *italic* (group 8)
      r'(_([^_]+)_)|'         // 9: _italic_ (group 10)
      r'(`([^`]+)`)|'         // 11: `code` (group 12)
      r'(~~(.*?)~~)',         // 13: ~~strike~~ (group 14)
      dotAll: true,
    );

    int lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final boldItalic = match.group(2);
      final bold1 = match.group(4);
      final bold2 = match.group(6);
      final italic1 = match.group(8);
      final italic2 = match.group(10);
      final code = match.group(12);
      final strike = match.group(14);

      if (boldItalic != null && boldItalic.isNotEmpty) {
        spans.add(TextSpan(
          text: boldItalic,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if ((bold1 != null && bold1.isNotEmpty) || (bold2 != null && bold2.isNotEmpty)) {
        final content = bold1 ?? bold2!;
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ));
      } else if ((italic1 != null && italic1.isNotEmpty) || (italic2 != null && italic2.isNotEmpty)) {
        final content = italic1 ?? italic2!;
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (code != null && code.isNotEmpty) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF334155), width: 0.8),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) * 0.9,
                color: const Color(0xFF38BDF8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ));
      } else if (strike != null && strike.isNotEmpty) {
        spans.add(TextSpan(
          text: strike,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    // Les formules prennent la couleur du texte : une formule n'est pas un lien.
    final effectiveMathColor = mathColor ?? effectiveStyle.color ?? context.colors.textPrimary;

    final normalizedText = autoDelimitMath(text);

    // Cas 1 : contient des délimiteurs $...$ ou $$...$$
    // Traitement exhaustif et exclusif — si $ est présent, tout le rendu est
    // géré ici. On ne passe PAS dans les cas 2 ou 3.
    if (normalizedText.contains(r'$')) {
      final spans = <InlineSpan>[];
      int lastEnd = 0;

      for (final match in _mathPattern.allMatches(normalizedText)) {
        if (match.start > lastEnd) {
          final textChunk = normalizedText.substring(lastEnd, match.start);
          spans.addAll(parseMarkdownSpans(textChunk, effectiveStyle));
        }

        final isDisplay = match.group(1) != null;
        final mathContent = (isDisplay ? match.group(1) : match.group(2))?.trim() ?? '';

        final double baseFontSize = effectiveStyle.fontSize ?? 14.0;
        final double mathFontSize = isDisplay
            ? (baseFontSize * 1.25).clamp(16.0, 24.0)
            : (baseFontSize * 1.05).clamp(12.0, 20.0);

        if (mathContent.isNotEmpty) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Math.tex(
                  mathContent,
                  mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
                  textStyle: TextStyle(
                    fontSize: mathFontSize,
                    color: effectiveMathColor,
                  ),
                  onErrorFallback: (_) => Text(
                    LatexToUnicodeConverter.convert(mathContent),
                    style: effectiveStyle.copyWith(
                      fontSize: mathFontSize,
                      color: effectiveMathColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ));
        }
        lastEnd = match.end;
      }

      if (lastEnd < normalizedText.length) {
        final textChunk = normalizedText.substring(lastEnd);
        spans.addAll(parseMarkdownSpans(textChunk, effectiveStyle));
      }

      return Text.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Cas 2 : la chaîne entière est une formule sans délimiteur (ex. « \\frac{1}{2}x^2 »).
    if (_looksLikePureFormula(normalizedText)) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Math.tex(
          normalizedText.trim(),
          mathStyle: MathStyle.text,
          textStyle: TextStyle(
            fontSize: (effectiveStyle.fontSize ?? 14) * 1.05,
            color: effectiveMathColor,
          ),
          onErrorFallback: (_) => Text(
            LatexToUnicodeConverter.convert(normalizedText),
            style: effectiveStyle.copyWith(color: effectiveMathColor),
          ),
        ),
      );
    }

    // Cas 3 : Texte normal avec syntaxe Markdown enrichie
    return Text.rich(
      TextSpan(children: parseMarkdownSpans(normalizedText, effectiveStyle)),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
