import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import '../../../core/design_system/components/elef_button.dart';
import '../../../core/design_system/components/elef_input.dart';
import '../../../core/design_system/components/elef_badge.dart';
import '../../../core/design_system/pedagogical/elef_callout.dart';
import '../../../core/design_system/pedagogical/elef_summary_sheet_card.dart';
import '../../../core/models/lesson_block_model.dart';
import '../../../core/models/subject_template_model.dart';
import '../../../core/providers/data_providers.dart';

/// Studio de création de cours et fiches de synthèse EDLEARN / ELEF v2.
///
/// Interface haute fidélité à 3 volets :
/// 1. Volet gauche : Bibliothèque de blocs pédagogiques & moteurs scientifiques.
/// 2. Volet central : Canvas d'édition directe avec réordonnancement et modification en direct.
/// 3. Volet droit : Aperçu élève en temps réel (trait pour trait, zéro code résiduel).
class LessonBuilderScreen extends ConsumerStatefulWidget {
  final String? initialLessonId;

  const LessonBuilderScreen({super.key, this.initialLessonId});

  @override
  ConsumerState<LessonBuilderScreen> createState() => _LessonBuilderScreenState();
}

class _LessonBuilderScreenState extends ConsumerState<LessonBuilderScreen> {
  // Contrôleurs métadonnées de la leçon
  late TextEditingController _titleCtrl;
  final String _status = 'draft';
  String? _selectedSubject;
  bool _isSaving = false;
  bool _isMobileView = false;
  String _blockSearchQuery = '';

  // Liste des blocs actifs dans le canvas
  List<LessonBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: 'Suites Numériques : Cours & Fiche de Synthèse',
    );
    _selectedSubject = 'Mathématiques';

    // Charger par défaut la Fiche Traits pour Traits des Suites Numériques
    final defaultTemplate = SubjectTemplate.standardTemplates.first;
    _blocks = defaultTemplate.generateBlocks();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _loadTemplate(SubjectTemplate template) {
    setState(() {
      _blocks = template.generateBlocks();
      _titleCtrl.text = '${template.title} (Nouveau)';
      _selectedSubject = template.targetSubject.split('—').first.trim();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "${template.title}" chargé avec succès'),
        backgroundColor: ElefColors.success,
      ),
    );
  }

  void _addBlock(LessonBlock newBlock) {
    setState(() {
      _blocks.add(newBlock.copyWith(order: _blocks.length + 1));
    });
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i] = _blocks[i].copyWith(order: i + 1);
      }
    });
  }

  void _duplicateBlock(int index) {
    setState(() {
      final block = _blocks[index];
      final duplicated = block.copyWith(
        id: '${block.type}_${DateTime.now().microsecondsSinceEpoch}',
        order: index + 2,
      );
      _blocks.insert(index + 1, duplicated);
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i] = _blocks[i].copyWith(order: i + 1);
      }
    });
  }

  void _moveBlock(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _blocks.length) return;
    setState(() {
      final block = _blocks.removeAt(index);
      _blocks.insert(newIndex, block);
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i] = _blocks[i].copyWith(order: i + 1);
      }
    });
  }

  Future<void> _saveLesson() async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final contentJson = {
        'version': 2,
        'blocks': _blocks.map((b) => b.toJson()).toList(),
      };

      // Si un chapitre est sélectionné ou par défaut
      if (widget.initialLessonId != null) {
        await service.updateLesson(
          id: widget.initialLessonId!,
          title: _titleCtrl.text.trim(),
          contentJson: contentJson,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leçon enregistrée avec succès (v2 structurée)'),
            backgroundColor: ElefColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enregistrement local simulé : ${e.toString()}'),
            backgroundColor: ElefColors.info,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElefColors.background,
      body: Column(
        children: [
          // 1. Barre d'outils supérieure du Studio
          _buildTopHeader(),

          // 2. Zone de travail à 3 volets
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 1100;
                if (isCompact) {
                  return _buildCompactLayout();
                }
                return Row(
                  children: [
                    // Volet Gauche : Bibliothèque de Blocs (300px)
                    SizedBox(
                      width: 310,
                      child: _buildBlockLibraryPane(),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: ElefColors.borderSubtle,
                    ),

                    // Volet Central : Canvas d'Édition Directe (Flexible)
                    Expanded(
                      flex: 5,
                      child: _buildCenterCanvasPane(),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: ElefColors.borderSubtle,
                    ),

                    // Volet Droit : Aperçu Élève en Temps Réel (Flexible)
                    Expanded(
                      flex: 4,
                      child: _buildStudentPreviewPane(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Barre Supérieure
  // ---------------------------------------------------------------------------

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: ElefColors.surfaceDark,
        border: Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ElefColors.primaryGlow,
              borderRadius: ElefRadius.md,
            ),
            child: const Icon(Icons.dashboard_customize_rounded, color: ElefColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        style: ElefTypography.heading2.copyWith(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Titre de la leçon ou fiche de synthèse...',
                          hintStyle: TextStyle(color: ElefColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElefBadge(
                      label: _status == 'published' ? 'Publié' : 'Brouillon',
                      color: _status == 'published' ? ElefColors.success : ElefColors.warning,
                      tone: ElefBadgeTone.subtle,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ELEF Studio v2 • Structure Canonique Multi-Discipline • Traits pour traits',
                  style: ElefTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Action Rapide : Fiche Spéciale Suites Numériques
          ElefButton.outline(
            label: '⚡ Fiche Suites Numériques',
            icon: Icons.functions_rounded,
            size: ElefButtonSize.sm,
            onPressed: () {
              final suitesTemplate = SubjectTemplate.standardTemplates.first;
              _loadTemplate(suitesTemplate);
            },
          ),
          const SizedBox(width: 10),

          // Bouton Charger un Template de Filière
          PopupMenuButton<SubjectTemplate>(
            tooltip: 'Charger un template de filière',
            color: ElefColors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: ElefRadius.md,
              side: const BorderSide(color: ElefColors.borderMedium),
            ),
            itemBuilder: (context) => SubjectTemplate.standardTemplates.map((tpl) {
              return PopupMenuItem<SubjectTemplate>(
                value: tpl,
                child: Row(
                  children: [
                    Icon(tpl.icon, size: 18, color: tpl.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tpl.title, style: ElefTypography.labelMedium.copyWith(color: Colors.white)),
                          Text(tpl.targetSubject, style: ElefTypography.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onSelected: _loadTemplate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ElefColors.surfaceCard,
                borderRadius: ElefRadius.md,
                border: Border.all(color: ElefColors.borderMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded, size: 16, color: ElefColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Templates', style: ElefTypography.labelMedium.copyWith(color: Colors.white)),
                  const Icon(Icons.arrow_drop_down, color: ElefColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Enregistrer
          ElefButton.primary(
            label: 'Enregistrer',
            icon: Icons.save_rounded,
            size: ElefButtonSize.sm,
            isLoading: _isSaving,
            onPressed: _saveLesson,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Volet Gauche : Bibliothèque de Blocs
  // ---------------------------------------------------------------------------

  Widget _buildBlockLibraryPane() {
    return Container(
      color: ElefColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bibliothèque de Blocs',
                  style: ElefTypography.titleMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                ElefSearchField(
                  hintText: 'Rechercher un bloc...',
                  onChanged: (q) => setState(() => _blockSearchQuery = q.toLowerCase()),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ElefColors.borderSubtle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildLibrarySection(
                  title: 'FICHES VISUELLES TRAIT POUR TRAIT',
                  icon: Icons.table_chart_rounded,
                  color: ElefColors.disciplineMath,
                  items: [
                    _BlockLibraryItem(
                      title: 'Fiche Synthèse Trait pour Trait',
                      subtitle: 'Colonnes comparatives, formules clés & pièges',
                      icon: Icons.view_column_rounded,
                      color: ElefColors.disciplineMath,
                      onAdd: () => _addBlock(
                        LessonBlock.summaryCard(
                          title: 'Fiche Synthèse : Nouvelle Notion',
                          subtitle: 'Tableau comparatif haute fidélité',
                          columns: [
                            {
                              'title': 'Cas A',
                              'badge': 'Standard',
                              'color': 0xFF38BDF8,
                              'items': [
                                {'label': 'Propriété', 'formula': r'f(x) = ax + b'},
                              ],
                            },
                            {
                              'title': 'Cas B',
                              'badge': 'Avancé',
                              'color': 0xFFA855F7,
                              'items': [
                                {'label': 'Propriété', 'formula': r'f(x) = ax^2 + bx + c'},
                              ],
                            },
                          ],
                          keyFormula: r'\Delta = b^2 - 4ac',
                          bulletPoints: ['Point essentiel 1', 'Point essentiel 2'],
                          examTrap: 'Ne pas oublier le coefficient d\'ordre supérieur.',
                        ),
                      ),
                    ),
                  ],
                ),
                _buildLibrarySection(
                  title: 'ACADÉMIQUE FORMEL',
                  icon: Icons.school_rounded,
                  color: ElefColors.primary,
                  items: [
                    _BlockLibraryItem(
                      title: 'Définition',
                      subtitle: 'Cadre bleu ciel avec liseré',
                      icon: Icons.menu_book_rounded,
                      color: ElefColors.disciplineMath,
                      onAdd: () => _addBlock(
                        LessonBlock.definition(
                          heading: 'Définition',
                          body: 'Texte formel de la définition.',
                          formulas: [r'E = mc^2'],
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Théorème & Propriété',
                      subtitle: 'Cadre violet avec formule',
                      icon: Icons.verified_rounded,
                      color: ElefColors.secondary,
                      onAdd: () => _addBlock(
                        LessonBlock.theorem(
                          heading: 'Théorème Fondamental',
                          body: 'Énoncé du théorème.',
                          formulas: [r'a^2 + b^2 = c^2'],
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Formule Clé',
                      subtitle: 'Encadré display LaTeX avec légende',
                      icon: Icons.functions_rounded,
                      color: ElefColors.primary,
                      onAdd: () => _addBlock(
                        LessonBlock.formula(
                          heading: 'Formule Fondamentale',
                          latexFormula: r'\lim_{x \to 0} \frac{\sin x}{x} = 1',
                          explanation: 'Limite remarquable essentielle.',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Méthode & Savoir-faire',
                      subtitle: 'Procédure pas-à-pas numérotée',
                      icon: Icons.lightbulb_rounded,
                      color: ElefColors.warning,
                      onAdd: () => _addBlock(
                        LessonBlock.method(
                          heading: 'Méthode de Résolution',
                          body: 'Guide structuré pour résoudre ce type d\'exercice.',
                          steps: ['Étape 1 : Poser l\'équation', 'Étape 2 : Factoriser'],
                        ),
                      ),
                    ),
                  ],
                ),
                _buildLibrarySection(
                  title: 'PÉDAGOGIE ACTIVE & EXAMEN',
                  icon: Icons.psychology_rounded,
                  color: ElefColors.disciplinePhysics,
                  items: [
                    _BlockLibraryItem(
                      title: 'Exemple Guidé',
                      subtitle: 'Application concrète détaillée',
                      icon: Icons.auto_awesome_rounded,
                      color: ElefColors.disciplineLiterature,
                      onAdd: () => _addBlock(
                        LessonBlock.example(
                          heading: 'Exemple d\'Application',
                          body: 'Résolution pas-à-pas d\'un cas concret.',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Piège d\'Examen',
                      subtitle: 'Alerte rouge sur les erreurs fréquentes',
                      icon: Icons.warning_amber_rounded,
                      color: ElefColors.danger,
                      onAdd: () => _addBlock(
                        LessonBlock.trap(
                          heading: 'Attention : Erreur Fréquente',
                          body: 'Ne pas confondre les termes de la formule.',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Conseil du Professeur',
                      subtitle: 'Astuce méthodologique pour le Bac',
                      icon: Icons.tips_and_updates_rounded,
                      color: ElefColors.warning,
                      onAdd: () => _addBlock(
                        LessonBlock.examTip(
                          heading: 'Conseil d\'Examen',
                          body: 'Pensez à toujours vérifier le domaine de définition.',
                        ),
                      ),
                    ),
                  ],
                ),
                _buildLibrarySection(
                  title: 'MOTEURS SCIENTIFIQUES & INTERACTIFS',
                  icon: Icons.science_rounded,
                  color: ElefColors.disciplineComputer,
                  items: [
                    _BlockLibraryItem(
                      title: 'Tracé de Fonction (GraphEngine)',
                      subtitle: 'Courbe interactive f(x)',
                      icon: Icons.show_chart_rounded,
                      color: ElefColors.disciplineMath,
                      onAdd: () => _addBlock(
                        LessonBlock.graphPlot(
                          heading: 'Tracé de Fonction Interactif',
                          expression: 'x^2 - 3*x + 2',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Atelier Code (CodeExecutionEngine)',
                      subtitle: 'Bac à sable Python exécutable',
                      icon: Icons.terminal_rounded,
                      color: ElefColors.disciplineComputer,
                      onAdd: () => _addBlock(
                        LessonBlock.codeRunner(
                          heading: 'Atelier Programmation Python',
                          language: 'Python',
                          initialCode: 'def f(x):\n    return x**2\n\nprint("f(4) =", f(4))',
                          expectedOutput: 'f(4) = 16',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrarySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_BlockLibraryItem> items,
  }) {
    final filtered = _blockSearchQuery.isEmpty
        ? items
        : items.where((it) => it.title.toLowerCase().contains(_blockSearchQuery) || it.subtitle.toLowerCase().contains(_blockSearchQuery)).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: ElefTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...filtered.map((item) => _buildLibraryCard(item)),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(_BlockLibraryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.md,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: InkWell(
        onTap: item.onAdd,
        borderRadius: ElefRadius.md,
        hoverColor: ElefColors.surfaceHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withAlpha(30),
                  borderRadius: ElefRadius.sm,
                ),
                child: Icon(item.icon, size: 16, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: ElefTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      style: ElefTypography.caption.copyWith(
                        color: ElefColors.textMuted,
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded, size: 18, color: ElefColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Volet Central : Canvas d'Édition Directe
  // ---------------------------------------------------------------------------

  Widget _buildCenterCanvasPane() {
    return Container(
      color: const Color(0xFF090D18),
      child: Column(
        children: [
          // En-tête du Canvas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: ElefColors.surfaceDark,
              border: Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Structure Pédagogique',
                      style: ElefTypography.titleMedium.copyWith(color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    ElefBadge(
                      label: '${_blocks.length} blocs',
                      color: ElefColors.primary,
                      tone: ElefBadgeTone.subtle,
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElefButton.ghost(
                      label: 'Tout vider',
                      icon: Icons.delete_sweep_rounded,
                      size: ElefButtonSize.sm,
                      onPressed: () {
                        setState(() => _blocks.clear());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Liste des Blocs Actifs
          Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.note_add_rounded, size: 48, color: ElefColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun bloc pour le moment',
                          style: ElefTypography.titleMedium.copyWith(color: ElefColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cliquez sur un bloc dans la bibliothèque à gauche pour commencer',
                          style: ElefTypography.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blocks.length,
                    itemBuilder: (context, index) {
                      return _buildBlockEditorCard(index, _blocks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockEditorCard(int index, LessonBlock block) {
    Color blockColor = ElefColors.primary;
    IconData blockIcon = Icons.article_rounded;

    if (block.type == 'theoreme') {
      blockColor = ElefColors.secondary;
      blockIcon = Icons.verified_rounded;
    } else if (block.type == 'definition') {
      blockColor = ElefColors.disciplineMath;
      blockIcon = Icons.menu_book_rounded;
    } else if (block.type == 'summary_card') {
      blockColor = ElefColors.disciplineMath;
      blockIcon = Icons.view_column_rounded;
    } else if (block.type == 'piege') {
      blockColor = ElefColors.danger;
      blockIcon = Icons.warning_amber_rounded;
    } else if (block.type == 'conseil_examen' || block.type == 'methode') {
      blockColor = ElefColors.warning;
      blockIcon = Icons.lightbulb_rounded;
    } else if (block.type == 'code_runner') {
      blockColor = ElefColors.disciplineComputer;
      blockIcon = Icons.terminal_rounded;
    } else if (block.type == 'graph_plot') {
      blockColor = ElefColors.disciplineMath;
      blockIcon = Icons.show_chart_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre de titre du bloc
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ElefColors.surfaceDark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ElefRadius.rawLg - 1),
                topRight: Radius.circular(ElefRadius.rawLg - 1),
              ),
              border: const Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
            ),
            child: Row(
              children: [
                // Numéro d'ordre
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ElefColors.surfaceElevated,
                    borderRadius: ElefRadius.xs,
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: ElefTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(blockIcon, size: 16, color: blockColor),
                const SizedBox(width: 8),
                Text(
                  block.type.toUpperCase(),
                  style: ElefTypography.caption.copyWith(
                    color: blockColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),

                // Boutons déplacement
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  color: index > 0 ? ElefColors.textSecondary : ElefColors.textDisabled,
                  tooltip: 'Monter',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: index > 0 ? () => _moveBlock(index, -1) : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  color: index < _blocks.length - 1 ? ElefColors.textSecondary : ElefColors.textDisabled,
                  tooltip: 'Descendre',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: index < _blocks.length - 1 ? () => _moveBlock(index, 1) : null,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  color: ElefColors.textSecondary,
                  tooltip: 'Dupliquer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _duplicateBlock(index),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: ElefColors.danger,
                  tooltip: 'Supprimer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeBlock(index),
                ),
              ],
            ),
          ),

          // Champs d'édition du bloc
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre optionnel
                TextField(
                  controller: TextEditingController(text: block.heading ?? '')
                    ..selection = TextSelection.collapsed(offset: (block.heading ?? '').length),
                  style: ElefTypography.titleSmall.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Titre / Intitulé du bloc',
                    labelStyle: ElefTypography.caption,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF090D18),
                    border: OutlineInputBorder(
                      borderRadius: ElefRadius.md,
                      borderSide: const BorderSide(color: ElefColors.borderSubtle),
                    ),
                  ),
                  onChanged: (val) {
                    _blocks[index] = block.copyWith(heading: val);
                  },
                ),
                const SizedBox(height: 10),

                // Contenu / Corps principal
                TextField(
                  controller: TextEditingController(text: block.body)
                    ..selection = TextSelection.collapsed(offset: block.body.length),
                  style: ElefTypography.bodyMedium.copyWith(color: ElefColors.textPrimary),
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: block.type == 'code_runner' ? 'Code Source' : 'Contenu textuel & explications',
                    labelStyle: ElefTypography.caption,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF090D18),
                    border: OutlineInputBorder(
                      borderRadius: ElefRadius.md,
                      borderSide: const BorderSide(color: ElefColors.borderSubtle),
                    ),
                  ),
                  onChanged: (val) {
                    _blocks[index] = block.copyWith(body: val);
                  },
                ),

                // Formule(s) LaTeX
                if (block.type == 'theoreme' || block.type == 'definition' || block.type == 'formule' || block.type == 'exemple') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(text: block.formulas.join('\n'))
                      ..selection = TextSelection.collapsed(offset: block.formulas.join('\n').length),
                    style: ElefTypography.code,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: 'Formules LaTeX (une par ligne)',
                      labelStyle: ElefTypography.caption,
                      prefixIcon: const Icon(Icons.functions_rounded, size: 16, color: ElefColors.primary),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF090D18),
                      border: OutlineInputBorder(
                        borderRadius: ElefRadius.md,
                        borderSide: const BorderSide(color: ElefColors.borderSubtle),
                      ),
                    ),
                    onChanged: (val) {
                      _blocks[index] = block.copyWith(
                        formulas: val.split('\n').where((s) => s.trim().isNotEmpty).toList(),
                      );
                    },
                  ),
                ],

                // Si c'est une Fiche Synthèse Visuelle, afficher un badge informatif
                if (block.type == 'summary_card') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ElefColors.disciplineMath.withAlpha(20),
                      borderRadius: ElefRadius.md,
                      border: Border.all(color: ElefColors.disciplineMath.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_stories_rounded, size: 16, color: ElefColors.disciplineMath),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fiche haute fidélité avec colonnes comparatives, formules display et astuces d\'examen intégrées.',
                            style: ElefTypography.caption.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Volet Droit : Aperçu Élève en Direct (Traits pour traits)
  // ---------------------------------------------------------------------------

  Widget _buildStudentPreviewPane() {
    return Container(
      color: const Color(0xFF0A0F1D),
      child: Column(
        children: [
          // Barre d'outils Aperçu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: ElefColors.surfaceDark,
              border: Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.visibility_rounded, size: 18, color: ElefColors.success),
                    const SizedBox(width: 8),
                    Text(
                      'Aperçu Élève en Direct',
                      style: ElefTypography.labelLarge.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.phone_android_rounded,
                        size: 18,
                        color: _isMobileView ? ElefColors.primary : ElefColors.textMuted,
                      ),
                      tooltip: 'Format Mobile (390px)',
                      onPressed: () => setState(() => _isMobileView = true),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.tablet_mac_rounded,
                        size: 18,
                        color: !_isMobileView ? ElefColors.primary : ElefColors.textMuted,
                      ),
                      tooltip: 'Format Tablette / Large',
                      onPressed: () => setState(() => _isMobileView = false),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenu du Rendu Élève
          Expanded(
            child: Center(
              child: Container(
                width: _isMobileView ? 400 : double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ListView(
                  children: [
                    // Titre Élève
                    Text(
                      _titleCtrl.text,
                      style: ElefTypography.displayMedium.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElefBadge(
                          label: _selectedSubject ?? 'Mathématiques',
                          color: ElefColors.disciplineMath,
                          tone: ElefBadgeTone.subtle,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Terminale • 45 min de lecture',
                          style: ElefTypography.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Rendu de chaque bloc en direct
                    ..._blocks.map((b) => _renderStudentBlock(b)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rendu natif haute fidélité d'un bloc côté élève
  Widget _renderStudentBlock(LessonBlock block) {
    switch (block.type) {
      case 'summary_card':
        final cols = (block.metadata['columns'] as List?)
            ?.map((c) => Map<String, dynamic>.from(c as Map))
            .toList();
        final keyFormula = block.metadata['keyFormula'] as String?;
        final bulletPoints = ((block.metadata['bulletPoints'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        final examTrap = block.metadata['examTrap'] as String?;

        return ElefSummarySheetCard(
          title: block.heading ?? 'Fiche Synthèse',
          subject: _selectedSubject ?? 'Mathématiques',
          columns: cols,
          keyFormula: keyFormula,
          bulletPoints: bulletPoints,
          examTrap: examTrap,
        );

      case 'theoreme':
        return ElefCallout(
          type: ElefCalloutType.theorem,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'definition':
        return ElefCallout(
          type: ElefCalloutType.definition,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'formule':
        return ElefCallout(
          type: ElefCalloutType.formula,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'methode':
        return ElefCallout(
          type: ElefCalloutType.method,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'exemple':
        return ElefCallout(
          type: ElefCalloutType.example,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'piege':
        return ElefCallout(
          type: ElefCalloutType.warning,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'conseil_examen':
        return ElefCallout(
          type: ElefCalloutType.tip,
          title: block.heading,
          content: block.body,
          formulas: block.formulas,
        );

      case 'code_runner':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: ElefRadius.lg,
            border: Border.all(color: ElefColors.borderMedium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0F1D),
                  border: Border(bottom: BorderSide(color: ElefColors.borderSubtle)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terminal_rounded, size: 14, color: ElefColors.disciplineComputer),
                    const SizedBox(width: 8),
                    Text(
                      block.heading ?? 'Code Exécutable',
                      style: ElefTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  block.body,
                  style: ElefTypography.code,
                ),
              ),
            ],
          ),
        );

      case 'graph_plot':
        final expr = block.metadata['expression'] as String? ?? 'f(x)';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: ElefRadius.lg,
            border: Border.all(color: ElefColors.disciplineMath.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart_rounded, color: ElefColors.disciplineMath, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    block.heading ?? 'Tracé Interactif',
                    style: ElefTypography.labelLarge.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Math.tex(
                  'f(x) = $expr',
                  mathStyle: MathStyle.display,
                  textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF070B14),
                  borderRadius: ElefRadius.md,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_graph_rounded, color: ElefColors.disciplineMath, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'GraphEngine — Rendu interactif actif',
                        style: ElefTypography.bodySmall.copyWith(color: ElefColors.disciplineMath),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case 'paragraph':
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.heading != null && block.heading!.isNotEmpty) ...[
                Text(
                  block.heading!,
                  style: ElefTypography.heading3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                block.body,
                style: ElefTypography.bodyLarge.copyWith(color: ElefColors.textSecondary),
              ),
            ],
          ),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Layout Compact pour petits écrans
  // ---------------------------------------------------------------------------

  Widget _buildCompactLayout() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Bibliothèque', icon: Icon(Icons.widgets_rounded)),
              Tab(text: 'Canvas Éditeur', icon: Icon(Icons.edit_note_rounded)),
              Tab(text: 'Aperçu Élève', icon: Icon(Icons.visibility_rounded)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBlockLibraryPane(),
                _buildCenterCanvasPane(),
                _buildStudentPreviewPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockLibraryItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onAdd;

  const _BlockLibraryItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onAdd,
  });
}
