import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/math_text.dart';
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
import 'media_library_screen.dart';

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
  ConsumerState<LessonBuilderScreen> createState() =>
      _LessonBuilderScreenState();
}

class _LessonBuilderScreenState extends ConsumerState<LessonBuilderScreen> {
  // Contrôleurs métadonnées de la leçon
  late TextEditingController _titleCtrl;
  final String _status = 'draft';
  String? _selectedSubject;
  bool _isSaving = false;
  bool _isLoading = false;
  String? _loadError;
  String? _lessonId;
  Map<String, dynamic> _originalContent = {};
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
    _lessonId = widget.initialLessonId;
    if (_lessonId != null) _loadLesson();
  }

  Future<void> _loadLesson() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final lesson = await ref
          .read(supabaseServiceProvider)
          .getLesson(_lessonId!);
      if (lesson == null) throw StateError('Leçon introuvable.');
      if (lesson.isPublished || lesson.contentJson['blocks'] is! List) {
        throw StateError(
          'Ouvrez cette leçon dans Leçons & Cours pour conserver son workflow et son format.',
        );
      }
      final blocks =
          (lesson.contentJson['blocks'] as List)
              .asMap()
              .entries
              .map(
                (e) => LessonBlock.fromJson(
                  Map<String, dynamic>.from(e.value as Map),
                  fallbackOrder: e.key,
                ),
              )
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      if (!mounted) return;
      setState(() {
        _titleCtrl.text = lesson.title;
        _originalContent = Map<String, dynamic>.from(lesson.contentJson);
        _blocks = blocks;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _chooseChapter() async {
    final subjects = await ref.read(
      subjectsProvider((countryId: null, includeInactive: false)).future,
    );
    if (!mounted) return null;
    final subjectId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choisir la matière du brouillon'),
        children: [
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune matière disponible.'),
            ),
          for (final subject in subjects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, subject.id),
              child: Text('${subject.name} (${subject.code})'),
            ),
        ],
      ),
    );
    if (subjectId == null || !mounted) return null;
    final chapters = await ref
        .read(supabaseServiceProvider)
        .fetchChapters(subjectId);
    if (!mounted) return null;
    final service = ref.read(supabaseServiceProvider);
    final classNames = <String, String>{};
    await Future.wait(
      chapters.map((c) => c.classNodeId).whereType<String>().toSet().map((
        id,
      ) async {
        final node = await service.getNode(id);
        classNames[id] = node?.name ?? 'Classe indisponible';
      }),
    );
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choisir le chapitre du brouillon'),
        children: [
          if (chapters.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun chapitre disponible. Créez-le dans l’arbre académique.',
              ),
            ),
          for (final chapter in chapters)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, chapter.id),
              child: Text(
                '${chapter.title}\nClasse : ${chapter.classNodeId == null ? "Toutes" : classNames[chapter.classNodeId]}',
              ),
            ),
        ],
      ),
    );
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

  Future<void> _saveLesson({bool submitForReview = false}) async {
    if (_isSaving || _isLoading || _loadError != null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un titre pour la leçon.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    var saved = false;
    try {
      final service = ref.read(supabaseServiceProvider);
      final chapterId = _lessonId == null ? await _chooseChapter() : null;
      if (!mounted || (_lessonId == null && chapterId == null)) return;
      final contentJson = {
        ..._originalContent,
        'version': 2,
        'blocks': _blocks.map((b) => b.toJson()).toList(),
      };

      // Si un chapitre est sélectionné ou par défaut
      if (_lessonId != null) {
        await service.updateLesson(
          id: _lessonId!,
          title: _titleCtrl.text.trim(),
          contentJson: contentJson,
          editedBy: service.client.auth.currentUser?.id,
        );
      } else {
        final siblings = await service.fetchLessonsForChapter(chapterId!);
        final nextOrder = siblings.fold<int>(
          0,
          (value, lesson) =>
              lesson.displayOrder >= value ? lesson.displayOrder + 1 : value,
        );
        final created = await service.createLesson(
          chapterId: chapterId,
          title: _titleCtrl.text.trim(),
          contentJson: contentJson,
          displayOrder: nextOrder,
        );
        if (created == null) {
          throw StateError('Le serveur n’a pas confirmé la création.');
        }
        _lessonId = created.id;
      }

      if (!mounted) return;
      _originalContent = contentJson;
      saved = true;
      ref.invalidate(lessonsProvider);
      ref.invalidate(chaptersWithLessonsProvider);

      if (submitForReview) {
        await service.submitLessonDraftForReview(_lessonId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitForReview
                  ? 'Brouillon enregistré et soumis pour validation.'
                  : 'Leçon enregistrée avec succès (v2 structurée)',
            ),
            backgroundColor: ElefColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved && submitForReview
                  ? 'Brouillon enregistré, mais soumission échouée : ${e.toString()}'
                  : 'Échec de l’enregistrement : ${e.toString()}',
            ),
            backgroundColor: ElefColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            TextButton(onPressed: _loadLesson, child: const Text('Réessayer')),
          ],
        ),
      );
    }
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
                    SizedBox(width: 310, child: _buildBlockLibraryPane()),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: ElefColors.borderSubtle,
                    ),

                    // Volet Central : Canvas d'Édition Directe (Flexible)
                    Expanded(flex: 5, child: _buildCenterCanvasPane()),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: ElefColors.borderSubtle,
                    ),

                    // Volet Droit : Aperçu Élève en Temps Réel (Flexible)
                    Expanded(flex: 4, child: _buildStudentPreviewPane()),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Retour aux leçons',
                ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ElefColors.primaryGlow,
                  borderRadius: ElefRadius.md,
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: ElefColors.primary,
                  size: 22,
                ),
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
                            style: ElefTypography.heading2.copyWith(
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Titre de la leçon ou fiche de synthèse...',
                              hintStyle: TextStyle(color: ElefColors.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElefBadge(
                          label: _status == 'published'
                              ? 'Publié'
                              : 'Brouillon',
                          color: _status == 'published'
                              ? ElefColors.success
                              : ElefColors.warning,
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
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Action Rapide : Fiche Spéciale Suites Numériques
              ElefButton.outline(
                label: '⚡ Fiche Suites Numériques',
                icon: Icons.functions_rounded,
                size: ElefButtonSize.sm,
                onPressed: () {
                  final suitesTemplate =
                      SubjectTemplate.standardTemplates.first;
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
                itemBuilder: (context) =>
                    SubjectTemplate.standardTemplates.map((tpl) {
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
                                  Text(
                                    tpl.title,
                                    style: ElefTypography.labelMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    tpl.targetSubject,
                                    style: ElefTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onSelected: _loadTemplate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ElefColors.surfaceCard,
                    borderRadius: ElefRadius.md,
                    border: Border.all(color: ElefColors.borderMedium),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_stories_rounded,
                        size: 16,
                        color: ElefColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Templates',
                        style: ElefTypography.labelMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: ElefColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Enregistrer
              ElefButton.secondary(
                label: 'Soumettre pour validation',
                icon: Icons.fact_check_outlined,
                size: ElefButtonSize.sm,
                isLoading: _isSaving,
                onPressed: () => _saveLesson(submitForReview: true),
              ),
              const SizedBox(width: 8),
              ElefButton.primary(
                label: 'Enregistrer',
                icon: Icons.save_rounded,
                size: ElefButtonSize.sm,
                isLoading: _isSaving,
                onPressed: _saveLesson,
              ),
            ],
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
                  style: ElefTypography.titleMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ElefSearchField(
                  hintText: 'Rechercher un bloc...',
                  onChanged: (q) =>
                      setState(() => _blockSearchQuery = q.toLowerCase()),
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
                                {
                                  'label': 'Propriété',
                                  'formula': r'f(x) = ax + b',
                                },
                              ],
                            },
                            {
                              'title': 'Cas B',
                              'badge': 'Avancé',
                              'color': 0xFFA855F7,
                              'items': [
                                {
                                  'label': 'Propriété',
                                  'formula': r'f(x) = ax^2 + bx + c',
                                },
                              ],
                            },
                          ],
                          keyFormula: r'\Delta = b^2 - 4ac',
                          bulletPoints: [
                            'Point essentiel 1',
                            'Point essentiel 2',
                          ],
                          examTrap:
                              'Ne pas oublier le coefficient d\'ordre supérieur.',
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
                          body:
                              'Guide structuré pour résoudre ce type d\'exercice.',
                          steps: [
                            'Étape 1 : Poser l\'équation',
                            'Étape 2 : Factoriser',
                          ],
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
                          body:
                              'Pensez à toujours vérifier le domaine de définition.',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Fiche Synthèse Visuelle',
                      subtitle: 'Tableau comparatif & formules mémo',
                      icon: Icons.view_column_rounded,
                      color: ElefColors.disciplineMath,
                      onAdd: () => _addBlock(
                        LessonBlock.summaryCard(
                          title: 'Fiche Synthèse : Suites Numériques',
                          subtitle: 'Comparatif direct et formules de référence',
                          keyFormula: r'S_n = \frac{n(u_1 + u_n)}{2} \quad \text{vs} \quad S_n = u_1 \frac{1 - q^n}{1 - q}',
                          columns: [
                            {
                              'title': 'Suites Arithmétiques',
                              'badge': 'Linéaire',
                              'items': [
                                {'label': 'Relation de récurrence', 'formula': r'u_{n+1} = u_n + r'},
                                {'label': 'Terme général', 'formula': r'u_n = u_0 + n \cdot r'},
                              ],
                            },
                            {
                              'title': 'Suites Géométriques',
                              'badge': 'Exponentielle',
                              'items': [
                                {'label': 'Relation de récurrence', 'formula': r'u_{n+1} = u_n \times q'},
                                {'label': 'Terme général', 'formula': r'u_n = u_0 \cdot q^n'},
                              ],
                            },
                          ],
                          bulletPoints: [
                            'Identifier le premier terme u_0 ou u_1 avant d\'appliquer la formule de somme.',
                            'La raison détermine le sens de variation et la convergence.',
                          ],
                          examTrap: 'Ne pas confondre la valeur du terme u_n et son rang n.',
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
                          initialCode:
                              'def f(x):\n    return x**2\n\nprint("f(4) =", f(4))',
                          expectedOutput: 'f(4) = 16',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Simulateur Circuit SPICE',
                      subtitle: 'Analyse RLC, Kirchhoff & Oscilloscope',
                      icon: Icons.electrical_services_rounded,
                      color: ElefColors.disciplinePhysics,
                      onAdd: () => _addBlock(
                        LessonBlock.virtualLab(
                          heading: 'Laboratoire Électronique SPICE',
                          labType: 'circuit',
                          description:
                              'Simulateur de circuit RLC déterministe avec oscilloscope temps réel.',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Simulateur Balistique 2D',
                      subtitle: 'Tir parabolique, gravité & frottements',
                      icon: Icons.rocket_launch_rounded,
                      color: ElefColors.warning,
                      onAdd: () => _addBlock(
                        LessonBlock.virtualLab(
                          heading: 'Laboratoire Balistique & Mouvement 2D',
                          labType: 'ballistics',
                          description:
                              'Étude du tir parabolique sous pesanteur avec calcul de flèche et portée.',
                        ),
                      ),
                    ),
                    _BlockLibraryItem(
                      title: 'Visualiseur Moléculaire 3D',
                      subtitle: 'Géométrie spatiale, atomes & liaisons',
                      icon: Icons.view_in_ar_rounded,
                      color: ElefColors.disciplineChemistry,
                      onAdd: () => _addBlock(
                        LessonBlock.virtualLab(
                          heading: 'Visualisation Moléculaire 3D',
                          labType: 'molecule',
                          description:
                              'Exploration 3D de la conformation moléculaire, angles et liaisons.',
                        ),
                      ),
                    ),
                  ],
                ),
                _buildLibrarySection(
                  title: 'RESSOURCES VISUELLES & MÉDIATHÈQUE',
                  icon: Icons.perm_media_rounded,
                  color: ElefColors.primary,
                  items: [
                    _BlockLibraryItem(
                      title: 'Image & Schéma Pédagogique',
                      subtitle: 'Illustration, figure géométrique ou schéma annoté',
                      icon: Icons.image_rounded,
                      color: ElefColors.primary,
                      onAdd: () => _addBlock(
                        LessonBlock.mediaImage(
                          heading: 'Figure Pédagogique',
                          imageUrl: '',
                          caption: 'Légende explicative de la figure',
                          altText: 'Figure scientifique explicative',
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
        : items
              .where(
                (it) =>
                    it.title.toLowerCase().contains(_blockSearchQuery) ||
                    it.subtitle.toLowerCase().contains(_blockSearchQuery),
              )
              .toList();

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
              Expanded(
                child: Text(
                  title,
                  style: ElefTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
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
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: ElefColors.primary,
              ),
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
              border: Border(
                bottom: BorderSide(color: ElefColors.borderSubtle),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Structure Pédagogique',
                      style: ElefTypography.titleMedium.copyWith(
                        color: Colors.white,
                      ),
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
                        const Icon(
                          Icons.note_add_rounded,
                          size: 48,
                          color: ElefColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun bloc pour le moment',
                          style: ElefTypography.titleMedium.copyWith(
                            color: ElefColors.textSecondary,
                          ),
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
                      final block = _blocks[index];
                      return _BlockEditorCardWidget(
                        key: ValueKey(block.id),
                        index: index,
                        block: block,
                        totalBlocks: _blocks.length,
                        onChanged: (updated) {
                          setState(() {
                            _blocks[index] = updated;
                          });
                        },
                        onMoveUp: () => _moveBlock(index, -1),
                        onMoveDown: () => _moveBlock(index, 1),
                        onDuplicate: () => _duplicateBlock(index),
                        onDelete: () => _removeBlock(index),
                      );
                    },
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
              border: Border(
                bottom: BorderSide(color: ElefColors.borderSubtle),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      size: 18,
                      color: ElefColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aperçu Élève en Direct',
                      style: ElefTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.phone_android_rounded,
                        size: 18,
                        color: _isMobileView
                            ? ElefColors.primary
                            : ElefColors.textMuted,
                      ),
                      tooltip: 'Format Mobile (390px)',
                      onPressed: () => setState(() => _isMobileView = true),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.tablet_mac_rounded,
                        size: 18,
                        color: !_isMobileView
                            ? ElefColors.primary
                            : ElefColors.textMuted,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: ListView(
                  children: [
                    // Titre Élève
                    Text(
                      _titleCtrl.text,
                      style: ElefTypography.displayMedium.copyWith(
                        color: Colors.white,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0F1D),
                  border: Border(
                    bottom: BorderSide(color: ElefColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.terminal_rounded,
                      size: 14,
                      color: ElefColors.disciplineComputer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      block.heading ?? 'Code Exécutable',
                      style: ElefTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(block.body, style: ElefTypography.code),
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
                  const Icon(
                    Icons.show_chart_rounded,
                    color: ElefColors.disciplineMath,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    block.heading ?? 'Tracé Interactif',
                    style: ElefTypography.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: MathText.formula(
                  'f(x) = $expr',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
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
                      const Icon(
                        Icons.auto_graph_rounded,
                        color: ElefColors.disciplineMath,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'GraphEngine — Rendu interactif actif',
                        style: ElefTypography.bodySmall.copyWith(
                          color: ElefColors.disciplineMath,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case 'virtual_lab':
        final labType = block.metadata['labType'] as String? ?? 'circuit';
        final labTitle = switch (labType) {
          'ballistics' => '🚀 Simulateur Balistique 2D',
          'molecule' => '🔬 Visualiseur Moléculaire 3D',
          'python' => '🐍 Bac à Sable Python WASM',
          'graph' => '📈 Grapheur Interactif 2D',
          _ => '⚡ Simulateur Circuit RLC SPICE',
        };
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: ElefRadius.lg,
            border: Border.all(color: ElefColors.disciplinePhysics.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_rounded, color: ElefColors.disciplinePhysics, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    block.heading ?? labTitle,
                    style: ElefTypography.labelLarge.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MathText(
                block.body,
                style: ElefTypography.bodyMedium.copyWith(color: ElefColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF070B14),
                  borderRadius: ElefRadius.md,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory_rounded, color: ElefColors.disciplinePhysics, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Moteur natif : $labTitle (interactif en direct dans l\'app élève)',
                        style: ElefTypography.caption.copyWith(color: ElefColors.disciplinePhysics),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case 'image':
        final imageUrl = (block.metadata['imageUrl'] as String?) ?? '';
        final caption = (block.metadata['caption'] as String?) ?? block.body;
        final altText = (block.metadata['altText'] as String?) ?? block.heading ?? 'Figure';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: ElefRadius.lg,
            border: Border.all(color: ElefColors.borderMedium),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (block.heading != null && block.heading!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: const Color(0xFF0A0F1D),
                  child: Row(
                    children: [
                      const Icon(Icons.image_rounded, size: 14, color: ElefColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        block.heading!,
                        style: ElefTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  height: 180,
                  fit: BoxFit.contain,
                  semanticLabel: altText,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: const Color(0xFF0A0F1D),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: ElefColors.textMuted),
                          const SizedBox(height: 4),
                          Text('Image indisponible', style: ElefTypography.caption.copyWith(color: ElefColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 100,
                  color: const Color(0xFF0A0F1D),
                  child: Center(
                    child: Text('Aucune image configurée', style: ElefTypography.caption.copyWith(color: ElefColors.textMuted)),
                  ),
                ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    caption,
                    style: ElefTypography.caption.copyWith(
                      color: ElefColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
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
              MathText(
                block.body,
                style: ElefTypography.bodyLarge.copyWith(
                  color: ElefColors.textSecondary,
                ),
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

/// Composant éditeur de carte de bloc à état persistant
/// Garantit l'absence de sauts de curseur et l'édition haute fidélité pour tous les types de blocs
class _BlockEditorCardWidget extends StatefulWidget {
  final int index;
  final LessonBlock block;
  final int totalBlocks;
  final ValueChanged<LessonBlock> onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _BlockEditorCardWidget({
    super.key,
    required this.index,
    required this.block,
    required this.totalBlocks,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_BlockEditorCardWidget> createState() => _BlockEditorCardWidgetState();
}

class _BlockEditorCardWidgetState extends State<_BlockEditorCardWidget> {
  late TextEditingController _headingCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _formulasCtrl;

  // Contrôleurs dédiés pour summary_card
  TextEditingController? _keyFormulaCtrl;
  TextEditingController? _bulletPointsCtrl;
  TextEditingController? _examTrapCtrl;
  TextEditingController? _col1TitleCtrl;
  TextEditingController? _col1BadgeCtrl;
  TextEditingController? _col1ItemsCtrl;
  TextEditingController? _col2TitleCtrl;
  TextEditingController? _col2BadgeCtrl;
  TextEditingController? _col2ItemsCtrl;

  // Configuration dédiée pour virtual_lab
  String _selectedLabType = 'circuit';

  // Contrôleurs dédiés pour image
  TextEditingController? _imageUrlCtrl;
  TextEditingController? _captionCtrl;
  TextEditingController? _altTextCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _headingCtrl = TextEditingController(text: widget.block.heading ?? '');
    _bodyCtrl = TextEditingController(text: widget.block.body);
    _formulasCtrl = TextEditingController(text: widget.block.formulas.join('\n'));

    if (widget.block.type == 'virtual_lab') {
      _selectedLabType = (widget.block.metadata['labType'] as String?) ?? 'circuit';
    } else if (widget.block.type == 'image') {
      final meta = widget.block.metadata;
      _imageUrlCtrl = TextEditingController(text: (meta['imageUrl'] as String?) ?? '');
      _captionCtrl = TextEditingController(text: (meta['caption'] as String?) ?? widget.block.body);
      _altTextCtrl = TextEditingController(text: (meta['altText'] as String?) ?? '');
    } else if (widget.block.type == 'summary_card') {
      final meta = widget.block.metadata;
      _keyFormulaCtrl = TextEditingController(text: (meta['keyFormula'] as String?) ?? '');
      final bullets = ((meta['bulletPoints'] as List?) ?? []).map((e) => e.toString()).toList();
      _bulletPointsCtrl = TextEditingController(text: bullets.join('\n'));
      _examTrapCtrl = TextEditingController(text: (meta['examTrap'] as String?) ?? '');

      final cols = (meta['columns'] as List?) ?? [];
      final col1 = cols.isNotEmpty && cols[0] is Map ? Map<String, dynamic>.from(cols[0] as Map) : <String, dynamic>{};
      final col2 = cols.length > 1 && cols[1] is Map ? Map<String, dynamic>.from(cols[1] as Map) : <String, dynamic>{};

      _col1TitleCtrl = TextEditingController(text: col1['title'] as String? ?? 'Cas A');
      _col1BadgeCtrl = TextEditingController(text: col1['badge'] as String? ?? '');
      final col1Items = (col1['items'] as List?) ?? [];
      final col1Lines = col1Items.map((item) {
        if (item is Map) {
          final l = item['label'] ?? '';
          final f = item['formula'] ?? '';
          return f.toString().isNotEmpty ? '$l | $f' : '$l';
        }
        return item.toString();
      }).join('\n');
      _col1ItemsCtrl = TextEditingController(text: col1Lines);

      _col2TitleCtrl = TextEditingController(text: col2['title'] as String? ?? 'Cas B');
      _col2BadgeCtrl = TextEditingController(text: col2['badge'] as String? ?? '');
      final col2Items = (col2['items'] as List?) ?? [];
      final col2Lines = col2Items.map((item) {
        if (item is Map) {
          final l = item['label'] ?? '';
          final f = item['formula'] ?? '';
          return f.toString().isNotEmpty ? '$l | $f' : '$l';
        }
        return item.toString();
      }).join('\n');
      _col2ItemsCtrl = TextEditingController(text: col2Lines);
    }
  }

  @override
  void didUpdateWidget(covariant _BlockEditorCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.id != oldWidget.block.id || widget.block.type != oldWidget.block.type) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _disposeControllers() {
    _headingCtrl.dispose();
    _bodyCtrl.dispose();
    _formulasCtrl.dispose();
    _keyFormulaCtrl?.dispose();
    _bulletPointsCtrl?.dispose();
    _examTrapCtrl?.dispose();
    _col1TitleCtrl?.dispose();
    _col1BadgeCtrl?.dispose();
    _col1ItemsCtrl?.dispose();
    _col2TitleCtrl?.dispose();
    _col2BadgeCtrl?.dispose();
    _col2ItemsCtrl?.dispose();
    _imageUrlCtrl?.dispose();
    _captionCtrl?.dispose();
    _altTextCtrl?.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _notifyChanged() {
    if (widget.block.type == 'virtual_lab') {
      final updated = widget.block.copyWith(
        heading: _headingCtrl.text.trim().isEmpty ? null : _headingCtrl.text,
        body: _bodyCtrl.text,
        metadata: {
          ...widget.block.metadata,
          'labType': _selectedLabType,
        },
      );
      widget.onChanged(updated);
    } else if (widget.block.type == 'image') {
      final updated = widget.block.copyWith(
        heading: _headingCtrl.text.trim().isEmpty ? null : _headingCtrl.text,
        body: _captionCtrl?.text ?? _bodyCtrl.text,
        metadata: {
          ...widget.block.metadata,
          'imageUrl': _imageUrlCtrl?.text.trim() ?? '',
          'caption': _captionCtrl?.text.trim() ?? '',
          'altText': _altTextCtrl?.text.trim() ?? '',
        },
      );
      widget.onChanged(updated);
    } else if (widget.block.type == 'summary_card') {
      List<Map<String, dynamic>> parseColumnItems(String text) {
        return text.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
          final parts = line.split('|');
          if (parts.length >= 2) {
            return {'label': parts[0].trim(), 'formula': parts.sublist(1).join('|').trim()};
          } else {
            final colParts = line.split(':');
            if (colParts.length >= 2) {
              return {'label': colParts[0].trim(), 'formula': colParts.sublist(1).join(':').trim()};
            }
            return {'label': line.trim(), 'formula': ''};
          }
        }).toList();
      }

      final col1 = {
        'title': _col1TitleCtrl?.text ?? 'Cas A',
        if ((_col1BadgeCtrl?.text ?? '').trim().isNotEmpty) 'badge': _col1BadgeCtrl!.text.trim(),
        'items': parseColumnItems(_col1ItemsCtrl?.text ?? ''),
      };
      final col2 = {
        'title': _col2TitleCtrl?.text ?? 'Cas B',
        if ((_col2BadgeCtrl?.text ?? '').trim().isNotEmpty) 'badge': _col2BadgeCtrl!.text.trim(),
        'items': parseColumnItems(_col2ItemsCtrl?.text ?? ''),
      };

      final bulletPoints = (_bulletPointsCtrl?.text ?? '')
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final keyFormula = _keyFormulaCtrl?.text.trim();
      final examTrap = _examTrapCtrl?.text.trim();

      final updated = widget.block.copyWith(
        heading: _headingCtrl.text.trim().isEmpty ? null : _headingCtrl.text,
        body: _bodyCtrl.text,
        formulas: keyFormula != null && keyFormula.isNotEmpty ? [keyFormula] : const [],
        metadata: {
          ...widget.block.metadata,
          'subtitle': _bodyCtrl.text,
          'keyFormula': keyFormula != null && keyFormula.isNotEmpty ? keyFormula : null,
          'bulletPoints': bulletPoints,
          'examTrap': examTrap != null && examTrap.isNotEmpty ? examTrap : null,
          'columns': [col1, col2],
        },
      );
      widget.onChanged(updated);
    } else {
      final formulas = _formulasCtrl.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final updated = widget.block.copyWith(
        heading: _headingCtrl.text.trim().isEmpty ? null : _headingCtrl.text,
        body: _bodyCtrl.text,
        formulas: formulas,
      );
      widget.onChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color blockColor = ElefColors.primary;
    IconData blockIcon = Icons.article_rounded;

    if (widget.block.type == 'theoreme') {
      blockColor = ElefColors.secondary;
      blockIcon = Icons.verified_rounded;
    } else if (widget.block.type == 'definition') {
      blockColor = ElefColors.disciplineMath;
      blockIcon = Icons.menu_book_rounded;
    } else if (widget.block.type == 'summary_card') {
      blockColor = ElefColors.disciplineMath;
      blockIcon = Icons.view_column_rounded;
    } else if (widget.block.type == 'piege') {
      blockColor = ElefColors.danger;
      blockIcon = Icons.warning_amber_rounded;
    } else if (widget.block.type == 'conseil_examen' || widget.block.type == 'methode') {
      blockColor = ElefColors.warning;
      blockIcon = Icons.lightbulb_rounded;
    } else if (widget.block.type == 'code_runner') {
      blockColor = ElefColors.disciplineComputer;
      blockIcon = Icons.terminal_rounded;
    } else if (widget.block.type == 'graph_plot') {
      blockColor = ElefColors.disciplineMath;
      blockIcon = Icons.show_chart_rounded;
    } else if (widget.block.type == 'virtual_lab') {
      blockColor = ElefColors.disciplinePhysics;
      blockIcon = Icons.biotech_rounded;
    } else if (widget.block.type == 'image') {
      blockColor = ElefColors.primary;
      blockIcon = Icons.image_rounded;
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
              border: const Border(
                bottom: BorderSide(color: ElefColors.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                // Numéro d'ordre
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ElefColors.surfaceElevated,
                    borderRadius: ElefRadius.xs,
                  ),
                  child: Text(
                    '#${widget.index + 1}',
                    style: ElefTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(blockIcon, size: 16, color: blockColor),
                const SizedBox(width: 8),
                Text(
                  widget.block.type.toUpperCase(),
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
                  color: widget.index > 0
                      ? ElefColors.textSecondary
                      : ElefColors.textDisabled,
                  tooltip: 'Monter',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.index > 0 ? widget.onMoveUp : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  color: widget.index < widget.totalBlocks - 1
                      ? ElefColors.textSecondary
                      : ElefColors.textDisabled,
                  tooltip: 'Descendre',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.index < widget.totalBlocks - 1
                      ? widget.onMoveDown
                      : null,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  color: ElefColors.textSecondary,
                  tooltip: 'Dupliquer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDuplicate,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: ElefColors.danger,
                  tooltip: 'Supprimer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDelete,
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
                  controller: _headingCtrl,
                  style: ElefTypography.titleSmall.copyWith(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.block.type == 'summary_card'
                        ? 'Titre de la Fiche Synthèse'
                        : 'Titre / Intitulé du bloc',
                    labelStyle: ElefTypography.caption,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF090D18),
                    border: OutlineInputBorder(
                      borderRadius: ElefRadius.md,
                      borderSide: const BorderSide(
                        color: ElefColors.borderSubtle,
                      ),
                    ),
                  ),
                  onChanged: (_) => _notifyChanged(),
                ),
                const SizedBox(height: 10),

                // Contenu / Corps principal
                TextField(
                  controller: _bodyCtrl,
                  style: ElefTypography.bodyMedium.copyWith(
                    color: ElefColors.textPrimary,
                  ),
                  maxLines: widget.block.type == 'summary_card' ? 2 : null,
                  decoration: InputDecoration(
                    labelText: widget.block.type == 'code_runner'
                        ? 'Code Source'
                        : widget.block.type == 'summary_card'
                            ? 'Sous-titre / Contextualisation de la fiche'
                            : 'Contenu textuel & explications',
                    labelStyle: ElefTypography.caption,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF090D18),
                    border: OutlineInputBorder(
                      borderRadius: ElefRadius.md,
                      borderSide: const BorderSide(
                        color: ElefColors.borderSubtle,
                      ),
                    ),
                  ),
                  onChanged: (_) => _notifyChanged(),
                ),

                // Formule(s) LaTeX standards
                if (widget.block.type == 'theoreme' ||
                    widget.block.type == 'definition' ||
                    widget.block.type == 'formule' ||
                    widget.block.type == 'exemple') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _formulasCtrl,
                    style: ElefTypography.code,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: 'Formules LaTeX (une par ligne)',
                      labelStyle: ElefTypography.caption,
                      prefixIcon: const Icon(
                        Icons.functions_rounded,
                        size: 16,
                        color: ElefColors.primary,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF090D18),
                      border: OutlineInputBorder(
                        borderRadius: ElefRadius.md,
                        borderSide: const BorderSide(
                          color: ElefColors.borderSubtle,
                        ),
                      ),
                    ),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ],

                // Éditeur complet dédié pour Laboratoire Virtuel Déterministe
                if (widget.block.type == 'virtual_lab') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1424),
                      borderRadius: ElefRadius.md,
                      border: Border.all(
                        color: ElefColors.disciplinePhysics.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.science_rounded,
                              size: 16,
                              color: ElefColors.disciplinePhysics,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'MOTEUR DÉTERMINISTE DU SIMULATEUR',
                              style: ElefTypography.caption.copyWith(
                                color: ElefColors.disciplinePhysics,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLabType,
                          dropdownColor: const Color(0xFF0F172A),
                          style: ElefTypography.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Type de Laboratoire Virtuel',
                            labelStyle: ElefTypography.caption,
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF090D18),
                            border: OutlineInputBorder(
                              borderRadius: ElefRadius.md,
                              borderSide: const BorderSide(
                                color: ElefColors.borderSubtle,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'circuit',
                              child: Text('⚡ Simulateur Circuit SPICE (Électrocinétique)'),
                            ),
                            DropdownMenuItem(
                              value: 'ballistics',
                              child: Text('🚀 Simulateur Balistique 2D (Mécanique Newtonienne)'),
                            ),
                            DropdownMenuItem(
                              value: 'molecule',
                              child: Text('🔬 Visualiseur Moléculaire 3D (Chimie)'),
                            ),
                            DropdownMenuItem(
                              value: 'python',
                              child: Text('🐍 Bac à Sable Python (Algorithmique WASM)'),
                            ),
                            DropdownMenuItem(
                              value: 'graph',
                              child: Text('📈 Grapheur Interactif 2D (Mathématiques)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedLabType = val);
                              _notifyChanged();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'L\'application élève instancie directement le moteur physique/mathématique natif déterministe correspondant.',
                          style: ElefTypography.caption.copyWith(
                            color: ElefColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Éditeur complet dédié pour Image & Schéma Pédagogique
                if (widget.block.type == 'image') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1424),
                      borderRadius: ElefRadius.md,
                      border: Border.all(
                        color: ElefColors.primary.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.image_rounded,
                              size: 16,
                              color: ElefColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'IMAGE & RESSOURCE MÉDIATHÈQUE',
                              style: ElefTypography.caption.copyWith(
                                color: ElefColors.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.photo_library_rounded, size: 14),
                              label: const Text('Choisir dans la Médiathèque', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogCtx) => Dialog(
                                    backgroundColor: ElefColors.surfaceDark,
                                    shape: RoundedRectangleBorder(borderRadius: ElefRadius.lg),
                                    child: SizedBox(
                                      width: 800,
                                      height: 600,
                                      child: Column(
                                        children: [
                                          AppBar(
                                            title: const Text('Sélectionner un média'),
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            automaticallyImplyLeading: false,
                                            actions: [
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                              ),
                                            ],
                                          ),
                                          Expanded(
                                            child: MediaLibraryScreen(
                                              onSelected: (asset) {
                                                _imageUrlCtrl?.text = asset.url;
                                                _notifyChanged();
                                                setState(() {});
                                                Navigator.of(dialogCtx).pop();
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _imageUrlCtrl,
                          style: ElefTypography.bodyMedium.copyWith(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'URL de l\'image (Storage Supabase ou HTTPS)',
                            labelStyle: ElefTypography.caption,
                            prefixIcon: const Icon(Icons.link_rounded, size: 16, color: ElefColors.primary),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF090D18),
                            border: OutlineInputBorder(
                              borderRadius: ElefRadius.md,
                              borderSide: const BorderSide(color: ElefColors.borderSubtle),
                            ),
                          ),
                          onChanged: (_) {
                            _notifyChanged();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _captionCtrl,
                          style: ElefTypography.bodyMedium.copyWith(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Légende explicative (affichée sous l\'image)',
                            labelStyle: ElefTypography.caption,
                            prefixIcon: const Icon(Icons.subtitles_rounded, size: 16, color: ElefColors.textSecondary),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF090D18),
                            border: OutlineInputBorder(
                              borderRadius: ElefRadius.md,
                              borderSide: const BorderSide(color: ElefColors.borderSubtle),
                            ),
                          ),
                          onChanged: (_) => _notifyChanged(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _altTextCtrl,
                          style: ElefTypography.bodyMedium.copyWith(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Texte alternatif (accessibilité / description vocale)',
                            labelStyle: ElefTypography.caption,
                            prefixIcon: const Icon(Icons.accessibility_new_rounded, size: 16, color: ElefColors.textSecondary),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF090D18),
                            border: OutlineInputBorder(
                              borderRadius: ElefRadius.md,
                              borderSide: const BorderSide(color: ElefColors.borderSubtle),
                            ),
                          ),
                          onChanged: (_) => _notifyChanged(),
                        ),
                        const SizedBox(height: 12),
                        if ((_imageUrlCtrl?.text.trim().isNotEmpty ?? false)) ...[
                          Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF070B14),
                              borderRadius: ElefRadius.md,
                              border: Border.all(color: ElefColors.borderSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              _imageUrlCtrl!.text.trim(),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.broken_image_rounded, color: ElefColors.textMuted, size: 28),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Impossible de charger l\'aperçu (URL invalide ou hors connexion)',
                                      style: ElefTypography.caption.copyWith(color: ElefColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Éditeur complet dédié pour Fiche Synthèse Visuelle
                if (widget.block.type == 'summary_card') ...[
                  const SizedBox(height: 12),
                  // Formule clé Display
                  TextField(
                    controller: _keyFormulaCtrl,
                    style: ElefTypography.code,
                    decoration: InputDecoration(
                      labelText: 'Formule Clé Principale Display (LaTeX)',
                      labelStyle: ElefTypography.caption,
                      prefixIcon: const Icon(
                        Icons.functions_rounded,
                        size: 16,
                        color: ElefColors.disciplineMath,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF090D18),
                      border: OutlineInputBorder(
                        borderRadius: ElefRadius.md,
                        borderSide: const BorderSide(
                          color: ElefColors.borderSubtle,
                        ),
                      ),
                    ),
                    onChanged: (_) => _notifyChanged(),
                  ),
                  const SizedBox(height: 12),

                  // Deux colonnes comparatives (Cas A & Cas B)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 520;
                      final col1Card = Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1424),
                          borderRadius: ElefRadius.md,
                          border: Border.all(
                            color: ElefColors.primary.withAlpha(60),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COLONNE 1 (CAS A)',
                              style: ElefTypography.caption.copyWith(
                                color: ElefColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _col1TitleCtrl,
                              style: ElefTypography.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Titre Colonne 1',
                                labelStyle: ElefTypography.caption,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF090D18),
                                border: OutlineInputBorder(
                                  borderRadius: ElefRadius.sm,
                                ),
                              ),
                              onChanged: (_) => _notifyChanged(),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _col1BadgeCtrl,
                              style: ElefTypography.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Badge (ex: Linéaire)',
                                labelStyle: ElefTypography.caption,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF090D18),
                                border: OutlineInputBorder(
                                  borderRadius: ElefRadius.sm,
                                ),
                              ),
                              onChanged: (_) => _notifyChanged(),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _col1ItemsCtrl,
                              style: ElefTypography.code,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Propriétés (Label | Formule LaTeX par ligne)',
                                labelStyle: ElefTypography.caption,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF090D18),
                                border: OutlineInputBorder(
                                  borderRadius: ElefRadius.sm,
                                ),
                              ),
                              onChanged: (_) => _notifyChanged(),
                            ),
                          ],
                        ),
                      );

                      final col2Card = Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1424),
                          borderRadius: ElefRadius.md,
                          border: Border.all(
                            color: ElefColors.secondary.withAlpha(60),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COLONNE 2 (CAS B)',
                              style: ElefTypography.caption.copyWith(
                                color: ElefColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _col2TitleCtrl,
                              style: ElefTypography.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Titre Colonne 2',
                                labelStyle: ElefTypography.caption,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF090D18),
                                border: OutlineInputBorder(
                                  borderRadius: ElefRadius.sm,
                                ),
                              ),
                              onChanged: (_) => _notifyChanged(),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _col2BadgeCtrl,
                              style: ElefTypography.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Badge (ex: Exponentielle)',
                                labelStyle: ElefTypography.caption,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF090D18),
                                border: OutlineInputBorder(
                                  borderRadius: ElefRadius.sm,
                                ),
                              ),
                              onChanged: (_) => _notifyChanged(),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _col2ItemsCtrl,
                              style: ElefTypography.code,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Propriétés (Label | Formule LaTeX par ligne)',
                                labelStyle: ElefTypography.caption,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF090D18),
                                border: OutlineInputBorder(
                                  borderRadius: ElefRadius.sm,
                                ),
                              ),
                              onChanged: (_) => _notifyChanged(),
                            ),
                          ],
                        ),
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: col1Card),
                            const SizedBox(width: 10),
                            Expanded(child: col2Card),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            col1Card,
                            const SizedBox(height: 10),
                            col2Card,
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Points clés bulletPoints
                  TextField(
                    controller: _bulletPointsCtrl,
                    style: ElefTypography.bodySmall.copyWith(
                      color: ElefColors.textPrimary,
                    ),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Points Clés & Astuces Mémo (un par ligne)',
                      labelStyle: ElefTypography.caption,
                      prefixIcon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: ElefColors.success,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF090D18),
                      border: OutlineInputBorder(
                        borderRadius: ElefRadius.md,
                        borderSide: const BorderSide(
                          color: ElefColors.borderSubtle,
                        ),
                      ),
                    ),
                    onChanged: (_) => _notifyChanged(),
                  ),
                  const SizedBox(height: 12),

                  // Piège d'examen examTrap
                  TextField(
                    controller: _examTrapCtrl,
                    style: ElefTypography.bodySmall.copyWith(
                      color: ElefColors.textPrimary,
                    ),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Piège d\'Examen Spécifique',
                      labelStyle: ElefTypography.caption,
                      prefixIcon: const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: ElefColors.danger,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF090D18),
                      border: OutlineInputBorder(
                        borderRadius: ElefRadius.md,
                        borderSide: const BorderSide(
                          color: ElefColors.danger,
                        ),
                      ),
                    ),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

