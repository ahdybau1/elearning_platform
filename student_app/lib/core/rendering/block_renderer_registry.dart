import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/content_block.dart';
import '../theme/student_theme.dart';

/// Registre `type de bloc -> widget`. Un seul point d'entrée (`BlockRendererRegistry.build`) pour tout
/// écran affichant du contenu pédagogique structuré (leçons aujourd'hui ; potentiellement PDF/offline
/// plus tard, en gardant la même source de données — voir CF-001 et U2.3 du cahier).
///
/// Un type non reconnu ne doit jamais faire planter l'app : il retombe sur un rendu paragraphe simple.
class BlockRendererRegistry {
  BlockRendererRegistry._();

  static Widget build(BuildContext context, ContentBlock block) {
    switch (block.type) {
      case 'theoreme':
      case 'theorem':
        return _card(
          context,
          block: block,
          icon: Icons.verified_rounded,
          color: context.colors.accentPrimary,
          defaultTitle: 'Théorème Majeur & Définition',
          bgColor: const Color(0xFF132338),
          textColor: Colors.white,
        );
      case 'definition':
        return _card(
          context,
          block: block,
          icon: Icons.menu_book_rounded,
          color: context.colors.accentIndigo,
          defaultTitle: 'Définition',
          bgColor: context.colors.card,
          textColor: context.colors.textPrimary,
        );
      case 'formule':
      case 'formula':
        return _formulaCard(context, block);
      case 'methode':
      case 'method':
        return _card(
          context,
          block: block,
          icon: Icons.lightbulb_outline_rounded,
          color: context.colors.accentAmber,
          defaultTitle: 'Méthode & Savoir-Faire',
          bgColor: context.colors.card,
          textColor: context.colors.textPrimary,
        );
      case 'exemple':
      case 'example':
        return _card(
          context,
          block: block,
          icon: Icons.auto_awesome_rounded,
          color: context.colors.accentPurple,
          defaultTitle: 'Exemple',
          bgColor: context.colors.card,
          textColor: context.colors.textPrimary,
        );
      case 'piege':
      case 'trap':
        return _card(
          context,
          block: block,
          icon: Icons.warning_amber_rounded,
          color: context.colors.accentRose,
          defaultTitle: 'Piège Classique d\'Examen',
          bgColor: const Color(0xFF2C161E),
          textColor: Colors.white,
        );
      case 'conseil_examen':
      case 'exam_tip':
        return _card(
          context,
          block: block,
          icon: Icons.tips_and_updates_rounded,
          color: context.colors.accentCyan,
          defaultTitle: 'Conseil d\'Examen',
          bgColor: context.colors.card,
          textColor: context.colors.textPrimary,
        );
      case 'paragraph':
      default:
        // Fallback sûr : y compris pour un type inconnu, jamais un widget vide ou un crash.
        return _paragraph(context, block);
    }
  }

  static Widget _paragraph(BuildContext context, ContentBlock block) {
    if (block.body.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      block.body,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: context.colors.textPrimary,
        height: 1.6,
      ),
    );
  }

  static Widget _card(
    BuildContext context, {
    required ContentBlock block,
    required IconData icon,
    required Color color,
    required String defaultTitle,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (block.heading?.trim().isNotEmpty ?? false) ? block.heading! : defaultTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (block.body.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              block.body,
              style: GoogleFonts.inter(fontSize: 14, color: textColor, height: 1.5),
            ),
          ],
          if (block.formulas.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...block.formulas.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    f,
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _formulaCard(BuildContext context, ContentBlock block) {
    final formulas = block.formulas.isNotEmpty ? block.formulas : [block.body];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.functions_rounded, color: context.colors.accentEmerald, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (block.heading?.trim().isNotEmpty ?? false)
                      ? block.heading!
                      : 'Formules & Propriétés Clés (LaTeX)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.accentEmerald,
                  ),
                ),
              ),
            ],
          ),
          if (block.formulas.isNotEmpty && block.body.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              block.body,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...formulas.where((f) => f.trim().isNotEmpty).map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.firaCode(
                        fontSize: 15,
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
