import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/pedagogy/widgets/interactive_function_graph.dart';
import '../../features/pedagogy/widgets/virtual_labs/ballistics_simulator_widget.dart';
import '../../features/pedagogy/widgets/virtual_labs/circuit_simulator_widget.dart';
import '../../features/pedagogy/widgets/virtual_labs/molecular_viewer_3d_widget.dart';
import '../../features/pedagogy/widgets/virtual_labs/python_sandbox_widget.dart';
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
          bgColor: context.colors.card,
          textColor: context.colors.textPrimary,
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
      // Blocs Moteurs Scientifiques & Laboratoires Virtuels Déterministes
      case 'virtual_lab':
      case 'simulation':
      case 'lab':
      case 'graph_plot':
      case 'code_runner':
        return _virtualLabBlock(context, block);
      // Blocs Multimédia & Schémas Pédagogiques
      case 'image':
      case 'media_image':
      case 'illustration':
        return _imageBlock(context, block);
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

    final purple = context.colors.accentPurple;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purple.withAlpha(80)),
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
              decoration: BoxDecoration(
                color: purple.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.balance_rounded,
                  color: purple, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RÈGLES ESSENTIELLES',
                    style: TextStyle(
                      color: purple,
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
                      color: purple.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: purple.withAlpha(50)),
                    ),
                    child: Column(
                      children: formulas
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.textPrimary,
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
    final emerald = context.colors.accentEmerald;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emerald.withAlpha(80)),
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
            Container(width: 5, color: emerald),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: emerald.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_rounded,
                          color: emerald, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXEMPLE GUIDÉ',
                            style: TextStyle(
                              color: emerald,
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
                              color: emerald.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: emerald.withAlpha(50)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'f(x) = x³ - 3x² + 1',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(Icons.arrow_downward_rounded,
                                    size: 16, color: emerald),
                                const SizedBox(height: 4),
                                Text(
                                  "f'(x) = 3x² - 6x",
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: emerald,
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
    final purple = context.colors.accentPurple;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purple.withAlpha(80)),
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
                decoration: BoxDecoration(
                  color: purple.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_outline_rounded,
                    color: purple, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'À REMARQUER',
                    style: TextStyle(
                      color: purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Ce qu\'il faut vraiment comprendre',
                    style: TextStyle(
                      color: context.colors.textMuted,
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
              color: purple.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: purple.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(Icons.adjust_rounded, color: purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "f'(a) est un nombre",
                        style: TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'serif',
                        ),
                      ),
                      Text(
                        "C'est la pente de la tangente au point d'abscisse a.",
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
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
              color: purple.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: purple.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline_rounded, color: purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "f' est une fonction",
                        style: TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'serif',
                        ),
                      ),
                      Text(
                        "Elle associe à chaque x la valeur f'(x).",
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
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

    final rose = context.colors.accentRose;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rose.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rose.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_rounded, color: rose, size: 22),
              const SizedBox(width: 8),
              Text(
                'ERREURS FRÉQUENTES',
                style: TextStyle(
                  color: rose,
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
                color: context.colors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: rose.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.close_rounded,
                      color: rose, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      err.replaceFirst('- ', '').replaceFirst('• ', ''),
                      style: TextStyle(
                        color: context.colors.textPrimary,
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
    final cyan = context.colors.accentCyan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cyan.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyan.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: cyan, size: 22),
              const SizedBox(width: 8),
              Text(
                'VÉRIFIE QUE TU AS COMPRIS',
                style: TextStyle(
                  color: cyan,
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
            style: TextStyle(
              color: context.colors.textPrimary,
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
                      SnackBar(
                        content: const Text('Exact ! Exemple : f(x) = x³ en 0 possède f\'(0)=0 avec un point d\'inflexion.'),
                        backgroundColor: cyan,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cyan),
                    backgroundColor: context.colors.card,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('OUI',
                      style: TextStyle(
                          color: cyan,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Pas tout à fait ! Pense à la fonction cube x³ au point x=0.'),
                        backgroundColor: context.colors.accentAmber,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.colors.border),
                    backgroundColor: context.colors.card,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('NON',
                      style: TextStyle(
                          color: context.colors.textSecondary,
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
        border: Border.all(color: disciplineColor.withAlpha(50), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              color: disciplineColor.withAlpha(15),
              border: Border(bottom: BorderSide(color: disciplineColor.withAlpha(30))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: disciplineColor.withAlpha(30),
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
              padding: const EdgeInsets.all(14),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colColor.withAlpha(45)),
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
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: colColor,
                                  ),
                                ),
                              ),
                              if (badgeText != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: colColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: colColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...items.map((item) {
                            final itemMap = Map<String, dynamic>.from(item as Map);
                            final label = itemMap['label'] as String? ?? '';
                            final formula = itemMap['formula'] as String? ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.colors.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.colors.border.withAlpha(35)),
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
                                padding: const EdgeInsets.only(bottom: 10),
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
                                padding: const EdgeInsets.symmetric(horizontal: 5),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: disciplineColor.withAlpha(45)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border.withAlpha(35)),
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
              padding: const EdgeInsets.fromLTRB(14, 5, 14, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.accentRose.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.accentRose.withAlpha(45)),
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

  // --- LABORATOIRES VIRTUELS & SIMULATEURS DÉTERMINISTES ---

  static Widget _virtualLabBlock(BuildContext context, ContentBlock block) {
    String labType = 'circuit';
    if (block.type == 'graph_plot') {
      labType = 'graph';
    } else if (block.type == 'code_runner') {
      labType = 'python';
    } else {
      final metaType = block.metadata['labType'] as String?;
      if (metaType != null && metaType.isNotEmpty) {
        labType = metaType.toLowerCase();
      }
    }

    return _VirtualLabCardWidget(block: block, labType: labType);
  }

  // --- BLOCS MULTIMÉDIA & SCHÉMAS PÉDAGOGIQUES ---

  static Widget _imageBlock(BuildContext context, ContentBlock block) {
    final imageUrl = (block.metadata['imageUrl'] as String?) ??
        (block.metadata['url'] as String?) ??
        (block.formulas.isNotEmpty ? block.formulas.first : '');
    final caption = (block.metadata['caption'] as String?)?.trim().isNotEmpty == true
        ? block.metadata['caption'] as String
        : (block.body.trim().isNotEmpty ? block.body.trim() : null);
    final altText = (block.metadata['altText'] as String?)?.trim().isNotEmpty == true
        ? block.metadata['altText'] as String
        : (block.heading ?? caption ?? 'Figure pédagogique');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (block.heading != null && block.heading!.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: context.colors.surface,
              child: Row(
                children: [
                  Icon(Icons.image_rounded, size: 16, color: context.colors.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      block.heading!.trim(),
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (imageUrl.trim().isNotEmpty)
            InkWell(
              onTap: () => _showImageZoomModal(context, imageUrl.trim(), altText, caption),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Semantics(
                    label: altText,
                    image: true,
                    child: Image.network(
                      imageUrl.trim(),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 180,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded, color: context.colors.textMuted, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Image inaccessible hors-ligne ou lien expiré',
                              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, color: context.colors.textMuted, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Aucune ressource visuelle fournie',
                    style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (caption != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              color: context.colors.surface.withAlpha(50),
              child: Text(
                caption,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  static void _showImageZoomModal(
    BuildContext context,
    String imageUrl,
    String altText,
    String? caption,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withAlpha(230),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      altText,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
            if (caption != null && caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  caption,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte interactive hébergeant un simulateur / laboratoire déterministe natif
class _VirtualLabCardWidget extends StatefulWidget {
  final ContentBlock block;
  final String labType;

  const _VirtualLabCardWidget({
    required this.block,
    required this.labType,
  });

  @override
  State<_VirtualLabCardWidget> createState() => _VirtualLabCardWidgetState();
}

class _VirtualLabCardWidgetState extends State<_VirtualLabCardWidget> {
  bool _isExpanded = true;

  Widget _buildEngineWidget(BuildContext context) {
    switch (widget.labType) {
      case 'ballistics':
        return const BallisticsSimulatorWidget();
      case 'molecule':
        return const MolecularViewer3DWidget();
      case 'python':
        return const PythonSandboxWidget();
      case 'graph':
        final expr = widget.block.metadata['expression'] as String? ??
            (widget.block.formulas.isNotEmpty ? widget.block.formulas.first : 'x^2 - 3*x + 2');
        return InteractiveFunctionGraph(
          functionSpec: MathFunctionSpec.fromExpression(
            expr,
            title: widget.block.heading,
          ),
          showObservationCard: true,
        );
      case 'circuit':
      default:
        return const CircuitSimulatorWidget();
    }
  }

  void _openFullscreen(BuildContext context) {
    if (widget.labType == 'graph') {
      final expr = widget.block.metadata['expression'] as String? ??
          (widget.block.formulas.isNotEmpty ? widget.block.formulas.first : 'x^2 - 3*x + 2');
      InteractiveFunctionGraph.showModal(
        context,
        expression: expr,
        title: widget.block.heading ?? 'Tracé de Fonction GraphEngine',
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(210),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.colors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    border: Border(
                      bottom: BorderSide(color: context.colors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_getLabIcon(), size: 20, color: _getLabColor(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.block.heading ?? _getDefaultTitle(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.of(ctx).pop(),
                        color: context.colors.textSecondary,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildEngineWidget(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getLabIcon() {
    switch (widget.labType) {
      case 'ballistics':
        return Icons.rocket_launch_rounded;
      case 'molecule':
        return Icons.view_in_ar_rounded;
      case 'python':
        return Icons.terminal_rounded;
      case 'graph':
        return Icons.show_chart_rounded;
      case 'circuit':
      default:
        return Icons.electrical_services_rounded;
    }
  }

  Color _getLabColor(BuildContext context) {
    switch (widget.labType) {
      case 'ballistics':
        return context.colors.accentPrimary;
      case 'molecule':
        return context.colors.accentEmerald;
      case 'python':
        return context.colors.accentCyan;
      case 'graph':
        return context.colors.accentPurple;
      case 'circuit':
      default:
        return context.colors.accentAmber;
    }
  }

  String _getDefaultTitle() {
    switch (widget.labType) {
      case 'ballistics':
        return 'Simulateur Balistique 2D (Mécanique)';
      case 'molecule':
        return 'Visualiseur Moléculaire 3D (Chimie)';
      case 'python':
        return 'Bac à Sable Algorithmique Python';
      case 'graph':
        return 'Tracé de Fonction Graphique 2D';
      case 'circuit':
      default:
        return 'Simulateur Circuit SPICE (Électronique)';
    }
  }

  String _getEngineBadge() {
    switch (widget.labType) {
      case 'ballistics':
        return 'MOTEUR NEWTONIEN RK4';
      case 'molecule':
        return 'GÉOMÉTRIE 3D COVALENTE';
      case 'python':
        return 'INTERPRÉTEUR PYODIDE WASM';
      case 'graph':
        return 'GRAPH ENGINE DÉTERMINISTE';
      case 'circuit':
      default:
        return 'SPICE 3F5 DÉTERMINISTE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final labColor = _getLabColor(context);
    final labIcon = _getLabIcon();
    final title = widget.block.heading ?? _getDefaultTitle();
    final badge = _getEngineBadge();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: labColor.withAlpha(50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: labColor.withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête du simulateur
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: labColor.withAlpha(15),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(15),
                bottom: _isExpanded ? Radius.zero : const Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(
                  color: _isExpanded ? labColor.withAlpha(40) : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: labColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(labIcon, size: 20, color: labColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: labColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: labColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (widget.block.body.isNotEmpty &&
                          widget.block.body != 'Expérimentation déterministe interactive.') ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.block.body,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: context.colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Bouton Plein écran
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  color: labColor,
                  tooltip: 'Mode plein écran',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _openFullscreen(context),
                ),

                // Bouton Réduire/Déplier
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                  color: context.colors.textSecondary,
                  tooltip: _isExpanded ? 'Réduire' : 'Déplier',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),

          // Contenu interactif du simulateur
          if (_isExpanded)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 540),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _buildEngineWidget(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
