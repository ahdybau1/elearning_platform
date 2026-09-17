import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../features/pedagogy/widgets/interactive_function_graph.dart';
import '../../features/pedagogy/widgets/scientific_tools_modal.dart';
import 'math_formula_view.dart';
import 'latex_to_unicode_converter.dart';

/// Renderer pédagogique universel pour les messages du Tuteur pq learn et textes mixtes.
///
/// Fonctionnalités complètes :
/// - Rendu vectoriel haute-définition des formules mathématiques ($...$ et $$...$$).
/// - Rendu Markdown riche complet : gras (**gras**), italique (*italique*), code (`code`), barré (~~barré~~).
/// - Titres structurés (#, ##, ###) avec typographie Outfit accentuée.
/// - Listes numérotées (1., 2.) avec pastilles circulaires cyan stylisées.
/// - Listes à puces (-, *) avec puces lumineuses cyan.
/// - Citations et conseils (>) sous forme de callouts glassmorphism avec bordure d'accent.
/// - Blocs de code (```lang ... ```) avec en-tête de syntaxe et bouton copier.
/// - Schémas et images pédagogiques (![légende](url)) avec chargement progressif, gestion d'erreur hors-ligne et modal plein écran avec zoom interactif.
/// - Détection automatique de fonctions et polynômes (ex: P(x) = 2x^2 - 4x - 6) avec actions intégrées (Tracé de courbe & Calcul SymPy).
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
    final blocks = _parseMessageBlocks(message);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Rendu séquencé de tous les blocs (titres, paragraphes, listes, images, formules)
        ...blocks.map((b) => _buildBlockWidget(context, b, style)),

        // 2. Bandeau d'actions interactives si une fonction ou un polynôme est détecté
        if (isAssistant && detectedFunction != null) ...[
          const SizedBox(height: 12),
          _buildInteractiveFunctionBar(context, detectedFunction),
        ],
      ],
    );
  }

  Widget _buildBlockWidget(BuildContext context, _MessageBlock block, TextStyle style) {
    final themeColor = isAssistant ? AppColors.primaryCyan : Colors.white;

    switch (block.type) {
      case _BlockType.displayMath:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MathFormulaView(
            formulaLatex: block.content,
            fontSize: 15,
            label: 'FORMULE ANALYSÉE',
            showCopyButton: false,
          ),
        );

      case _BlockType.image:
        return _buildImageBlock(context, block);

      case _BlockType.heading1:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            block.content,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        );

      case _BlockType.heading2:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            block.content,
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: isAssistant ? AppColors.primaryCyan : Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        );

      case _BlockType.heading3:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3.5,
                height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  block.content,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.numberedList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryCyan.withAlpha(120),
                    width: 1.1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  block.extra ?? '1',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryCyan,
                  ),
                ),
              ),
              Expanded(
                child: InlineLatexText(
                  block.content,
                  style: style,
                  mathColor: themeColor,
                ),
              ),
            ],
          ),
        );

      case _BlockType.bulletList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 5, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 7, right: 10, left: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withAlpha(120),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InlineLatexText(
                  block.content,
                  style: style,
                  mathColor: themeColor,
                ),
              ),
            ],
          ),
        );

      case _BlockType.blockquote:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B).withAlpha(160),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: AppColors.primaryCyan, width: 3.5),
            ),
          ),
          child: InlineLatexText(
            block.content,
            style: style.copyWith(
              color: const Color(0xFFE2E8F0),
              fontStyle: FontStyle.italic,
            ),
            mathColor: AppColors.primaryCyan,
          ),
        );

      case _BlockType.codeBlock:
        return _buildCodeBlock(context, block);

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InlineLatexText(
            block.content,
            style: style,
            mathColor: themeColor,
          ),
        );
    }
  }

  Widget _buildImageBlock(BuildContext context, _MessageBlock block) {
    final url = block.content;
    final alt = block.alt ?? 'Illustration pédagogique';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primaryCyan.withAlpha(90), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showImageZoomModal(context, url, alt),
            child: Stack(
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    final total = loadingProgress.expectedTotalBytes;
                    final loaded = loadingProgress.cumulativeBytesLoaded;
                    final progress = total != null && total > 0 ? loaded / total : null;

                    return Container(
                      height: 180,
                      color: const Color(0xFF090D16),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2.5,
                              color: AppColors.primaryCyan,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Chargement de l\'illustration...',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      color: const Color(0xFF090D16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.image_not_supported_rounded, color: Colors.white38, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              alt,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Illustration indisponible ou connexion requise',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withAlpha(60)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Agrandir',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (alt.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF090D16),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_size_select_actual_outlined, size: 13, color: AppColors.primaryCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alt,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showImageZoomModal(BuildContext context, String url, String alt) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020617).withAlpha(245),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.primaryCyan.withAlpha(120), width: 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      alt,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, _MessageBlock block) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  block.extra?.toUpperCase() ?? 'CODE',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B949E),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copié !'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: Color(0xFF8B949E)),
                      SizedBox(width: 4),
                      Text('Copier', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                block.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: Color(0xFFE6EDF3),
                ),
              ),
            ),
          ),
        ],
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
    if (text.trim().isEmpty) return blocks;

    // 1. Détecter les blocs multi-lignes $$...$$, \[...\], ```lang ... ```
    final specialBlockRegex = RegExp(
      r'(\$\$(.*?)\$\$)|'                       // 1, 2: $$ math $$
      r'(\\\[(.*?)\\\])|'                       // 3, 4: \[ math \]
      r'(```([a-zA-Z0-9_-]*)\r?\n(.*?)```)',    // 5, 6, 7: ```lang code ```
      dotAll: true,
    );

    int lastEnd = 0;
    for (final match in specialBlockRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final textPart = text.substring(lastEnd, match.start);
        _parseStandardBlocks(textPart, blocks);
      }

      final math1 = match.group(2);
      final math2 = match.group(4);
      final codeLang = match.group(6);
      final codeContent = match.group(7);

      if (math1 != null || math2 != null) {
        final formula = (math1 ?? math2)!.trim();
        if (formula.isNotEmpty) {
          blocks.add(_MessageBlock(
            type: _BlockType.displayMath,
            content: formula,
          ));
        }
      } else if (codeContent != null) {
        blocks.add(_MessageBlock(
          type: _BlockType.codeBlock,
          content: codeContent.trim(),
          extra: codeLang?.trim().isNotEmpty == true ? codeLang!.trim() : 'code',
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      _parseStandardBlocks(remaining, blocks);
    }

    return blocks.isEmpty ? [_MessageBlock(type: _BlockType.paragraph, content: text)] : blocks;
  }

  void _parseStandardBlocks(String chunk, List<_MessageBlock> blocks) {
    final lines = chunk.split(RegExp(r'\r?\n'));
    final paragraphBuffer = StringBuffer();

    void flushParagraph() {
      final str = paragraphBuffer.toString().trim();
      if (str.isNotEmpty) {
        blocks.add(_MessageBlock(type: _BlockType.paragraph, content: str));
        paragraphBuffer.clear();
      }
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      // 1. Image Markdown: ![alt](url)
      final imgMatch = RegExp(r'!\[(.*?)\]\((https?:\/\/[^\s\)]+)\)').firstMatch(trimmed);
      if (imgMatch != null) {
        final before = trimmed.substring(0, imgMatch.start).trim();
        final after = trimmed.substring(imgMatch.end).trim();
        if (before.isNotEmpty) {
          if (paragraphBuffer.isNotEmpty) paragraphBuffer.write(' ');
          paragraphBuffer.write(before);
        }
        flushParagraph();
        blocks.add(_MessageBlock(
          type: _BlockType.image,
          content: imgMatch.group(2)!,
          alt: imgMatch.group(1)?.trim().isNotEmpty == true
              ? imgMatch.group(1)!.trim()
              : 'Schéma pédagogique',
        ));
        if (after.isNotEmpty) {
          paragraphBuffer.write(after);
        }
        continue;
      }

      // 2. Titres Markdown
      final h1Match = RegExp(r'^#\s+(.*)$').firstMatch(trimmed);
      if (h1Match != null) {
        flushParagraph();
        blocks.add(_MessageBlock(type: _BlockType.heading1, content: h1Match.group(1)!.trim()));
        continue;
      }

      final h2Match = RegExp(r'^##\s+(.*)$').firstMatch(trimmed);
      if (h2Match != null) {
        flushParagraph();
        blocks.add(_MessageBlock(type: _BlockType.heading2, content: h2Match.group(1)!.trim()));
        continue;
      }

      final h3Match = RegExp(r'^###\s+(.*)$').firstMatch(trimmed);
      if (h3Match != null) {
        flushParagraph();
        blocks.add(_MessageBlock(type: _BlockType.heading3, content: h3Match.group(1)!.trim()));
        continue;
      }

      // 3. Citations / Callouts
      final quoteMatch = RegExp(r'^>\s*(.*)$').firstMatch(trimmed);
      if (quoteMatch != null) {
        flushParagraph();
        blocks.add(_MessageBlock(type: _BlockType.blockquote, content: quoteMatch.group(1)!.trim()));
        continue;
      }

      // 4. Listes numérotées
      final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        flushParagraph();
        blocks.add(_MessageBlock(
          type: _BlockType.numberedList,
          extra: numMatch.group(1)!,
          content: numMatch.group(2)!.trim(),
        ));
        continue;
      }

      // 5. Listes à puces
      final bulletMatch = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        flushParagraph();
        blocks.add(_MessageBlock(
          type: _BlockType.bulletList,
          content: bulletMatch.group(1)!.trim(),
        ));
        continue;
      }

      // Paragraphe classique
      if (paragraphBuffer.isNotEmpty) {
        paragraphBuffer.write(' ');
      }
      paragraphBuffer.write(trimmed);
    }

    flushParagraph();
  }
}

enum _BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  numberedList,
  bulletList,
  blockquote,
  codeBlock,
  displayMath,
  image,
}

class _MessageBlock {
  final _BlockType type;
  final String content;
  final String? extra;
  final String? alt;

  const _MessageBlock({
    required this.type,
    required this.content,
    this.extra,
    this.alt,
  });

  bool get isDisplayMath => type == _BlockType.displayMath;
}
