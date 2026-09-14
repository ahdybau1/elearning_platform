import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../features/pedagogy/widgets/interactive_function_graph.dart';
import '../../features/pedagogy/widgets/scientific_tools_modal.dart';
import 'math_formula_view.dart';
import 'latex_to_unicode_converter.dart';

/// Renderer pédagogique universel pour les messages de l'assistant numérique et textes mixtes.
///
/// Fonctionnalités :
/// - Rendu vectoriel haute-définition des formules sans aucune fuite de code brut.
/// - Détection automatique de fonctions et polynômes (ex: P(x) = 2x^2 - 4x - 6, f(x) = x^3 - 3x + 1).
/// - Boutons d'action interactifs intégrés pour tracer la courbe, résoudre avec SymPy et afficher les variations.
class AiMessageBubbleRenderer extends StatelessWidget {
  final String message;
  final bool isAssistant;
  final TextStyle? baseStyle;

  const AiMessageBubbleRenderer({
    super.key,
    required this.message,
    bool? isAi,
    bool isAssistant = true,
    this.baseStyle,
  }) : isAssistant = isAi ?? isAssistant;

  /// Détecte la première formule ou expression polynomiale/fonctionnelle dans le message
  static String? detectFunctionExpression(String text) {
    // 1. Recherche d'une fonction explicite type f(x) = ... ou P(x) = ...
    final funcRegex = RegExp(
      r'([a-zA-Z]\(x\)\s*=\s*[^,.;\n\r$]+)',
      caseSensitive: false,
    );
    final mFunc = funcRegex.firstMatch(text);
    if (mFunc != null) {
      return mFunc.group(1)?.trim();
    }

    // 2. Recherche d'un polynôme quadratique isolé (ex: 2x^2 - 4x - 6 ou x^2 - 4)
    final polyRegex = RegExp(
      r'([+\-]?[0-9]*\.?[0-9]*\*?x(?:\^2|²)(?:\s*[+\-]\s*[0-9]*\.?[0-9]*\*?x)?(?:\s*[+\-]\s*[0-9]+\.?[0-9]*)?)',
      caseSensitive: false,
    );
    final mPoly = polyRegex.firstMatch(text);
    if (mPoly != null && (mPoly.group(1)?.length ?? 0) >= 3) {
      return mPoly.group(1)?.trim();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ??
        GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          color: isAssistant ? const Color(0xFFF1F5F9) : Colors.white,
        );

    final detectedFunction = detectFunctionExpression(message);

    // Découpage en blocs (paragraphes et équations centrées $$...$$)
    final blocks = _parseMessageBlocks(message);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Rendu des paragraphes et formules
        ...blocks.map((b) => _buildBlockWidget(context, b, style)),

        // 2. Bandeau d'actions interactives si une fonction ou un polynôme est détecté
        if (isAssistant && detectedFunction != null) ...[
          const SizedBox(height: 14),
          _buildInteractiveFunctionBar(context, detectedFunction),
        ],
      ],
    );
  }

  Widget _buildBlockWidget(BuildContext context, _MessageBlock block, TextStyle style) {
    if (block.isDisplayMath) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: MathFormulaView(
          formulaLatex: block.content,
          fontSize: 15,
          label: 'FORMULE ANALYSÉE',
          showCopyButton: false,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InlineLatexText(
        block.content,
        style: style,
        mathColor: isAssistant ? AppColors.primaryCyan : Colors.white,
      ),
    );
  }

  Widget _buildInteractiveFunctionBar(BuildContext context, String rawFunction) {
    final cleanExpr = LatexToUnicodeConverter.convert(rawFunction);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primaryCyan.withAlpha(90), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryCyan.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_graph_rounded, color: AppColors.primaryCyan, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fonction identifiée : $cleanExpr',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.timeline_rounded, size: 15),
                label: const Text(
                  'Tracer la courbe & tangente',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  InteractiveFunctionGraph.showModal(
                    context,
                    expression: rawFunction,
                    title: 'Tracé de $cleanExpr',
                  );
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tealSuccess,
                  side: const BorderSide(color: AppColors.tealSuccess, width: 1.1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.calculate_rounded, size: 15),
                label: const Text(
                  'Calculer avec SymPy',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ScientificToolsModal.show(
                    context,
                    initialQuery: rawFunction,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_MessageBlock> _parseMessageBlocks(String text) {
    final blocks = <_MessageBlock>[];
    final displayMathRegex = RegExp(r'\$\$(.*?)\$\$|\\\[(.*?)\\\]', dotAll: true);

    int lastEnd = 0;
    for (final match in displayMathRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final textPart = text.substring(lastEnd, match.start).trim();
        if (textPart.isNotEmpty) {
          blocks.add(_MessageBlock(content: textPart, isDisplayMath: false));
        }
      }

      final mathFormula = (match.group(1) ?? match.group(2))?.trim() ?? '';
      if (mathFormula.isNotEmpty) {
        blocks.add(_MessageBlock(content: mathFormula, isDisplayMath: true));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        blocks.add(_MessageBlock(content: remaining, isDisplayMath: false));
      }
    }

    return blocks.isEmpty ? [_MessageBlock(content: text, isDisplayMath: false)] : blocks;
  }
}

class _MessageBlock {
  final String content;
  final bool isDisplayMath;

  const _MessageBlock({required this.content, required this.isDisplayMath});
}
