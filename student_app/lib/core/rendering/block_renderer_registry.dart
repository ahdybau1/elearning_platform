import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/content_block.dart';
import '../theme/student_theme.dart';
import 'math_formula_view.dart';

/// Registre `type de bloc -> widget`. Un seul point d'entrée (`BlockRendererRegistry.build`) pour tout
/// écran affichant du contenu pédagogique structuré (leçons aujourd'hui ; potentiellement PDF/offline
/// plus tard, en gardant la même source de données — voir CF-001 et U2.3 du cahier).
///
/// Intègre les composants visuels haute-fidélité des maquettes EDLEARN 2026 :
/// - Situation de départ (orange avec icône industrielle)
/// - Ce que tu vas apprendre (violet avec puces validées)
/// - Cours et définitions (bleu avec typographie mathématique)
/// - Règles essentielles (violette encadrée avec formules clés)
/// - Exemple guidé (menthe verte avec dérivée pas à pas)
/// - À remarquer / Erreurs fréquentes / Vérification rapide Oui/Non.
class BlockRendererRegistry {
  BlockRendererRegistry._();

  static Widget build(BuildContext context, ContentBlock block) {
    switch (block.type) {
      // Fiche de Synthèse Visuelle Haute Fidélité Traits pour Traits
      case 'summary_card':
      case 'summary_sheet':
      case 'fiche_synthese':
        return _summaryCard(context, block);

      // 1. Situation de départ (Orange)
      case 'situation_depart':
      case 'situation':
        return _situationDepartCard(context, block);

      // 2. Objectifs d'apprentissage (Violet)
      case 'objectifs':
      case 'learning_objectives':
        return _objectivesCard(context, block);

      // 3. Règles essentielles encadrées (Violette)
      case 'regles_essentielles':
      case 'essential_rules':
        return _essentialRulesCard(context, block);

      // 4. Exemple guidé (Vert)
      case 'exemple_guide':
      case 'guided_example':
        return _guidedExampleCard(context, block);

      // 5. À remarquer (Comparaison pédagogique)
      case 'a_remarquer':
      case 'remarks':
        return _remarksCard(context, block);

      // 6. Erreurs fréquentes (Rouge)
      case 'erreurs_frequentes':
      case 'frequent_errors':
      case 'piege':
      case 'trap':
        return _frequentErrorsCard(context, block);

      // 7. Vérifie que tu as compris (Quiz rapide Oui/Non)
      case 'verifie_comprehension':
      case 'quick_check':
        return _quickCheckCard(context, block);

      // Blocs académiques classiques
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
      case 'cours':
      case 'cours_theorie':
        return _courseDefinitionCard(context, block);
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
        return _paragraph(context, block);
    }
  }

  // --- BLOCS HAUTE-FIDÉLITÉ EDLEARN 2026 ---

  /// 1. SITUATION DE DÉPART (Orange)
  static Widget _situationDepartCard(BuildContext context, ContentBlock block) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEA580C).withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.factory_rounded, color: Color(0xFFEA580C), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (block.heading?.trim().isNotEmpty ?? false)
                      ? block.heading!.toUpperCase()
                      : 'SITUATION DE DÉPART',
                  style: const TextStyle(
                    color: Color(0xFFEA580C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  block.body.isNotEmpty
                      ? block.body
                      : "Une entreprise veut réduire le coût de fabrication d'un objet. Comment déterminer la quantité qui rend ce coût minimal ?",
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. CE QUE TU VAS APPRENDRE (Violet)
  static Widget _objectivesCard(BuildContext context, ContentBlock block) {
    final objectives = block.body.split('\n').where((s) => s.trim().isNotEmpty).toList();
    final items = objectives.isNotEmpty
        ? objectives
        : [
            'Déterminer la fonction dérivée',
            'Utiliser les règles de dérivation',
            'Interpréter le signe de f\'',
          ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7E22CE).withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7E22CE).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.track_changes_rounded, color: Color(0xFF7E22CE), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (block.heading?.trim().isNotEmpty ?? false)
                      ? block.heading!.toUpperCase()
                      : 'CE QUE TU VAS APPRENDRE',
                  style: const TextStyle(
                    color: Color(0xFF7E22CE),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (obj) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF7E22CE), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            obj.replaceFirst('- ', '').replaceFirst('• ', ''),
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  /// 3. COURS (Bleu)
  static Widget _courseDefinitionCard(BuildContext context, ContentBlock block) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.accentPrimary.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.accentPrimary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.menu_book_rounded, color: context.colors.accentPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (block.heading?.trim().isNotEmpty ?? false)
                      ? block.heading!.toUpperCase()
                      : 'COURS & DÉFINITION',
                  style: TextStyle(
                    color: context.colors.accentPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  block.body.isNotEmpty
                      ? block.body
                      : "Si f est dérivable sur un intervalle, sa fonction dérivée associe à chaque nombre x le nombre dérivé f'(x).",
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. RÈGLES ESSENTIELLES (Violet clair encadré)
  static Widget _essentialRulesCard(BuildContext context, ContentBlock block) {
    final formulas = block.formulas.isNotEmpty
        ? block.formulas
        : ['(u + v)\' = u\' + v\'', '(uv)\' = u\'v + uv\''];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF6B21A8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.balance_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RÈGLES ESSENTIELLES',
                    style: TextStyle(
                      color: Color(0xFF6B21A8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Column(
                      children: formulas
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                f,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 5. EXEMPLE GUIDÉ (Vert)
  static Widget _guidedExampleCard(BuildContext context, ContentBlock block) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: const Color(0xFF16A34A)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXEMPLE GUIDÉ',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Column(
                              children: const [
                                Text(
                                  'f(x) = x³ - 3x² + 1',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Icon(Icons.arrow_downward_rounded,
                                    size: 16, color: Color(0xFF16A34A)),
                                SizedBox(height: 4),
                                Text(
                                  "f'(x) = 3x² - 6x",
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 6. À REMARQUER (Comparatif f'(a) vs f')
  static Widget _remarksCard(BuildContext context, ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF7E22CE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'À REMARQUER',
                    style: TextStyle(
                      color: Color(0xFF7E22CE),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Ce qu\'il faut vraiment comprendre',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ligne 1 : f'(a) est un nombre
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              children: const [
                Icon(Icons.adjust_rounded, color: Color(0xFF7E22CE), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "f'(a) est un nombre",
                        style: TextStyle(
                          color: Color(0xFF7E22CE),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'serif',
                        ),
                      ),
                      Text(
                        "C'est la pente de la tangente au point d'abscisse a.",
                        style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Ligne 2 : f' est une fonction
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              children: const [
                Icon(Icons.timeline_rounded, color: Color(0xFF7E22CE), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "f' est une fonction",
                        style: TextStyle(
                          color: Color(0xFF7E22CE),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'serif',
                        ),
                      ),
                      Text(
                        "Elle associe à chaque x la valeur f'(x).",
                        style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 7. ERREURS FRÉQUENTES (Rouge)
  static Widget _frequentErrorsCard(BuildContext context, ContentBlock block) {
    final errors = block.body.split('\n').where((s) => s.trim().isNotEmpty).toList();
    final items = errors.isNotEmpty
        ? errors
        : [
            'Confondre f(a) et f\'(a)',
            'Oublier de factoriser avant l\'étude du signe',
            'Lire le signe de f au lieu de celui de f\'',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cancel_rounded, color: Color(0xFFE11D48), size: 22),
              SizedBox(width: 8),
              Text(
                'ERREURS FRÉQUENTES',
                style: TextStyle(
                  color: Color(0xFFBE123C),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (err) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE4E6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.close_rounded,
                      color: Color(0xFFE11D48), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      err.replaceFirst('- ', '').replaceFirst('• ', ''),
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 8. VÉRIFIE QUE TU AS COMPRIS (Oui / Non)
  static Widget _quickCheckCard(BuildContext context, ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.help_outline_rounded,
                  color: Color(0xFF0F766E), size: 22),
              SizedBox(width: 8),
              Text(
                'VÉRIFIE QUE TU AS COMPRIS',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            block.body.isNotEmpty
                ? block.body
                : "Une fonction peut-elle avoir f'(a) = 0 sans maximum ni minimum ?",
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exact ! Exemple : f(x) = x³ en 0 possède f\'(0)=0 avec un point d\'inflexion.'),
                        backgroundColor: Color(0xFF0F766E),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF14B8A6)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('OUI',
                      style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pas tout à fait ! Pense à la fonction cube x³ au point x=0.'),
                        backgroundColor: Color(0xFFEA580C),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('NON',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BLOCS ACADÉMIQUES EXISTANTS ---

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
            InlineLatexText(
              block.body,
              style: GoogleFonts.inter(fontSize: 14, color: textColor, height: 1.5),
            ),
          ],
          if (block.formulas.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...block.formulas.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MathFormulaView(
                  formulaLatex: f,
                  fontSize: 14,
                  label: 'FORMULE ASSOCIÉE',
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
                      : 'Formules & Propriétés Clés',
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
            InlineLatexText(
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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MathFormulaView(
                    formulaLatex: f,
                    fontSize: 15,
                    label: 'PROPRIÉTÉ CLÉ',
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Fiche Récapitulative Visuelle Haute Fidélité Traits pour Traits
  static Widget _summaryCard(BuildContext context, ContentBlock block) {
    final title = block.heading ?? 'Fiche Synthèse';
    final subtitle = block.body.isNotEmpty ? block.body : (block.metadata['subtitle'] as String? ?? '');
    final cols = (block.metadata['columns'] as List?)
        ?.map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final keyFormula = (block.metadata['keyFormula'] as String?) ??
        (block.formulas.isNotEmpty ? block.formulas.first : null);
    final bulletPoints = ((block.metadata['bulletPoints'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final examTrap = block.metadata['examTrap'] as String?;

    final disciplineColor = context.colors.accentCyan;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: disciplineColor.withAlpha(90), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de la Fiche
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: disciplineColor.withAlpha(25),
              border: Border(bottom: BorderSide(color: disciplineColor.withAlpha(50))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: disciplineColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: disciplineColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Colonnes Comparatives (Arithmétique vs Géométrique)
          if (cols != null && cols.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final colWidgets = cols.map((col) {
                    final colTitle = col['title'] as String? ?? 'Colonne';
                    final badgeText = col['badge'] as String?;
                    final colColor = col['color'] != null
                        ? Color(col['color'] as int)
                        : disciplineColor;
                    final items = (col['items'] as List?) ?? [];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colColor.withAlpha(70)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  colTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colColor,
                                  ),
                                ),
                              ),
                              if (badgeText != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...items.map((item) {
                            final itemMap = Map<String, dynamic>.from(item as Map);
                            final label = itemMap['label'] as String? ?? '';
                            final formula = itemMap['formula'] as String? ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF070B14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.colors.border.withAlpha(50)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (label.isNotEmpty) ...[
                                    Text(
                                      label,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (formula.isNotEmpty)
                                    MathFormulaView(
                                      formulaLatex: formula,
                                      fontSize: 14,
                                      isDisplayMode: true,
                                      showCopyButton: false,
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList();

                  if (isNarrow) {
                    return Column(
                      children: colWidgets
                          .map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: w,
                              ))
                          .toList(),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: colWidgets
                        .map((w) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: w,
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ],

          // Formule Centrale Générale
          if (keyFormula != null && keyFormula.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1020),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: disciplineColor.withAlpha(70)),
                ),
                child: Column(
                  children: [
                    Text(
                      'FORMULE DE SYNTHÈSE',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: disciplineColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MathFormulaView(
                      formulaLatex: keyFormula,
                      fontSize: 15,
                      isDisplayMode: true,
                      showCopyButton: true,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Points Méthodologiques
          if (bulletPoints.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 15, color: disciplineColor),
                        const SizedBox(width: 8),
                        Text(
                          'Points Clés & Astuces',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...bulletPoints.map((pt) => Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Icon(Icons.circle, size: 4, color: disciplineColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pt,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],

          // Piège Classique d'Examen
          if (examTrap != null && examTrap.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.accentRose.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.accentRose.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: context.colors.accentRose),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PIÈGE CLASSIQUE DU BAC / EXAMEN',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: context.colors.accentRose,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            examTrap,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: context.colors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
