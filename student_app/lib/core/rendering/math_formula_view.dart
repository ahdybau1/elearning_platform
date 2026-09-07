import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import 'latex_to_unicode_converter.dart';

/// Moteurs de rendu mathématique supportés (Cahier IA Zéro-Coût §5 & Cahier Technique §2)
enum MathRendererEngine {
  katex,
  mathjax,
}

/// Gestionnaire global du moteur de rendu mathématique
class MathRendererSettings {
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
    this.fontSize = 15.0,
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
    final effectiveTextColor = textColor ?? const Color(0xFFE2E8F0);
    final sanitizedFormula = _sanitizeLatex(formulaLatex);

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
            color: const Color(0xFF090D16),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: themeColor.withAlpha(80),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec label de formule, sélecteur de moteur et bouton Copier
              Row(
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
                            label ?? 'FORMULE OFFICIELLE',
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
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Colors.white.withAlpha(160),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copier la formule',
                              style: TextStyle(
                                color: Colors.white.withAlpha(160),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

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
                      child: Math.tex(
                        cleanLine,
                        mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
                        textStyle: TextStyle(
                          fontSize: fontSize,
                          color: effectiveTextColor,
                        ),
                        onErrorFallback: (err) {
                          // Fallback mathématique Unicode propre sans jamais exposer de code TeX brut à l'élève
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

  static final RegExp _mathPattern = RegExp(r'\$\$(.*?)\$\$|\$(.*?)\$', dotAll: true);

  static bool containsMath(String s) {
    if (s.contains(r'$')) return true;
    final mathTriggers = [
      r'\begin{',
      r'\Delta',
      r'\frac',
      r'\sqrt',
      r'\sum',
      r'\int',
      r'\infty',
      r'\lim',
      r'\times',
      r'\cdot',
      r'\in',
      r'\forall',
      r'\exists',
      r'\le',
      r'\ge',
      r'\neq',
      r'\mathbb',
      r'\pm',
      r'\approx',
    ];
    return mathTriggers.any((t) => s.contains(t));
  }

  /// Prépare le texte en encadrant automatiquement les fragments LaTeX isolés sans $...$
  static String autoDelimitMath(String input) {
    if (input.contains(r'$')) return input;

    // Détecte les commandes LaTeX courantes non délimitées et les englobe dans $...$
    var processed = input;
    final mathCommandRegex = RegExp(
      r'(\\(?:frac\{[^}]*\}\{[^}]*\}|sqrt(?:\[[^\]]*\])?\{[^}]*\}|lim_\{[^}]*\}|Delta|infty|le|ge|neq|times|cdot|in|forall|exists|mathbb\{[A-Z]\}|pm|approx|[a-zA-Z]\(x\)\s*=\s*[^,.;\n]+))',
    );

    processed = processed.replaceAllMapped(mathCommandRegex, (m) {
      final token = m.group(1) ?? '';
      return '\$$token\$';
    });

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final effectiveMathColor = mathColor ?? effectiveStyle.color ?? const Color(0xFF0EA5E9);

    final normalizedText = autoDelimitMath(text);

    // Cas 1 : contient des délimiteurs $...$ ou $$...$$
    if (normalizedText.contains(r'$')) {
      final spans = <InlineSpan>[];
      int lastEnd = 0;

      for (final match in _mathPattern.allMatches(normalizedText)) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(
            text: normalizedText.substring(lastEnd, match.start),
            style: effectiveStyle,
          ));
        }

        final isDisplay = match.group(1) != null;
        final mathContent = (isDisplay ? match.group(1) : match.group(2))?.trim() ?? '';

        if (mathContent.isNotEmpty) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Math.tex(
                mathContent,
                mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
                textStyle: TextStyle(
                  fontSize: effectiveStyle.fontSize ?? 14,
                  color: effectiveMathColor,
                  fontWeight: effectiveStyle.fontWeight,
                ),
                onErrorFallback: (_) => Text(
                  LatexToUnicodeConverter.convert(mathContent),
                  style: effectiveStyle.copyWith(
                    color: effectiveMathColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ));
        }
        lastEnd = match.end;
      }

      if (lastEnd < normalizedText.length) {
        spans.add(TextSpan(
          text: normalizedText.substring(lastEnd),
          style: effectiveStyle,
        ));
      }

      return Text.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Cas 2 : Pas de $ mais formule directe
    if (containsMath(normalizedText)) {
      return Math.tex(
        normalizedText,
        mathStyle: MathStyle.text,
        textStyle: TextStyle(
          fontSize: effectiveStyle.fontSize ?? 14,
          color: effectiveMathColor,
        ),
        onErrorFallback: (_) => Text(
          LatexToUnicodeConverter.convert(normalizedText),
          style: effectiveStyle,
        ),
      );
    }

    // Cas 3 : Texte normal
    return Text(
      normalizedText,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

