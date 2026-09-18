import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';
import '../../../core/widgets/math_text.dart';
import '../widgets/media_attachment_picker.dart';

/// Studio de création et d'édition d'exercices pédagogiques EDLEARN.
///
/// Interface dédiée plein écran offrant un espace spacieux, structuré en 3 volets :
/// 1. Énoncé & Médias (formulation, LaTeX en direct, type & format).
/// 2. Choix & Corrigé Pédagogique (QCM interactif, solution détaillée, indices progressifs).
/// 3. Rattachement Académique & Métadonnées (3 niveaux d'indépendance, classe, compétences, accès).
class ExerciseStudioScreen extends ConsumerStatefulWidget {
  final String? exerciseId;
  final Exercise? existingExercise;

  const ExerciseStudioScreen({
    super.key,
    this.exerciseId,
    this.existingExercise,
  });

  @override
  ConsumerState<ExerciseStudioScreen> createState() => _ExerciseStudioScreenState();
}

class _ExerciseStudioScreenState extends ConsumerState<ExerciseStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contrôleurs de texte
  late TextEditingController _titleController;
  late TextEditingController _statementController;
  late TextEditingController _solutionController;
  late TextEditingController _hintsController;
  late TextEditingController _skillsController;
  late TextEditingController _prerequisitesController;

  // Typologie & Format
  ExerciseType _selectedType = ExerciseType.training;
  ExerciseFormat _selectedFormat = ExerciseFormat.qcm;
  ExerciseDifficulty _selectedDifficulty = ExerciseDifficulty.facile;
  String _selectedTier = 'gratuit';

  // Rattachement académique (3 niveaux d'indépendance)
  String _selectedLevelTab = 'Niveau 1'; // 'Niveau 1', 'Niveau 2', 'Niveau 3'
  String? _selectedClassNodeId;
  String? _selectedChapterId;
  String? _selectedLessonId;
  String? _selectedTermId;

  // Options QCM
  List<TextEditingController> _optionControllers = [];
  int? _correctOptionIndex;

  // Médias
  List<MediaAsset> _statementMedia = [];
  List<MediaAsset> _solutionMedia = [];

  // États
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  Exercise? _currentExercise;

  // États du Live Canvas interactif
  bool _previewShowCorrection = false;
  int? _previewSelectedOptionIndex;
  int _previewRevealedHints = 0;

  void _refreshCanvas() {
    if (mounted) setState(() {});
  }

  String _currentAdminId() => ref.read(authProvider).valueOrNull?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _titleController = TextEditingController()..addListener(_refreshCanvas);
    _statementController = TextEditingController()..addListener(_refreshCanvas);
    _solutionController = TextEditingController()..addListener(_refreshCanvas);
    _hintsController = TextEditingController()..addListener(_refreshCanvas);
    _skillsController = TextEditingController();
    _prerequisitesController = TextEditingController();

    if (widget.existingExercise != null) {
      _initFromExercise(widget.existingExercise!);
    } else if (widget.exerciseId != null) {
      _loadExerciseFromDb(widget.exerciseId!);
    } else {
      _initNewExercise();
    }
  }

  void _initNewExercise() {
    _titleController.text = 'Nouvel exercice';
    _selectedType = ExerciseType.training;
    _selectedFormat = ExerciseFormat.qcm;
    _selectedDifficulty = ExerciseDifficulty.facile;
    _selectedTier = 'gratuit';
    _selectedLevelTab = 'Niveau 1';

    // 2 options initiales pour le QCM
    _optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    _correctOptionIndex = 0;
  }

  void _initFromExercise(Exercise ex) {
    _currentExercise = ex;
    _titleController.text = ex.title;
    _statementController.text = ex.instructionsJson['statement'] as String? ?? '';
    _solutionController.text = ex.solutionJson['correction'] as String? ?? '';
    _selectedType = ex.type;
    _selectedFormat = ex.format;
    _selectedDifficulty = ex.difficulty;
    _selectedTier = ex.minSubscriptionTier;

    _selectedClassNodeId = ex.classNodeId;
    _selectedChapterId = ex.chapterId;
    _selectedLessonId = ex.lessonId;
    _selectedTermId = ex.termId;

    if (ex.lessonId != null) {
      _selectedLevelTab = 'Niveau 1';
    } else if (ex.chapterId != null) {
      _selectedLevelTab = 'Niveau 2';
    } else {
      _selectedLevelTab = 'Niveau 3';
    }

    // Médias énoncé & solution
    _statementMedia = ((ex.instructionsJson['media'] as List?) ?? [])
        .map(
          (m) => MediaAsset(
            id: '',
            filename: m['filename'] as String? ?? '',
            type: m['type'] as String? ?? 'document',
            url: m['url'] as String? ?? '',
            uploadedBy: '',
          ),
        )
        .toList();

    _solutionMedia = ((ex.solutionJson['media'] as List?) ?? [])
        .map(
          (m) => MediaAsset(
            id: '',
            filename: m['filename'] as String? ?? '',
            type: m['type'] as String? ?? 'document',
            url: m['url'] as String? ?? '',
            uploadedBy: '',
          ),
        )
        .toList();

    // Options QCM
    final existingOpts = (ex.instructionsJson['options'] as List?)
            ?.map((o) => o.toString())
            .toList() ??
        <String>[];
    _optionControllers = (existingOpts.isEmpty ? ['', ''] : existingOpts)
        .map((o) => TextEditingController(text: o))
        .toList();
    _correctOptionIndex = ex.solutionJson['correct_index'] as int? ?? 0;

    // Métadonnées
    _hintsController.text = ex.hints.join('\n');
    _skillsController.text = ex.skills.join(', ');
    _prerequisitesController.text = ex.prerequisites.join(', ');
  }

  Future<void> _loadExerciseFromDb(String id) async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final ex = await service.getExercise(id);
      if (ex != null && mounted) {
        setState(() => _initFromExercise(ex));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur de chargement: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_refreshCanvas);
    _statementController.removeListener(_refreshCanvas);
    _solutionController.removeListener(_refreshCanvas);
    _hintsController.removeListener(_refreshCanvas);
    _tabController.dispose();
    _titleController.dispose();
    _statementController.dispose();
    _solutionController.dispose();
    _hintsController.dispose();
    _skillsController.dispose();
    _prerequisitesController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveExercise({bool publishNow = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('Le titre de l\'exercice est obligatoire.');
      return;
    }

    if (_selectedLevelTab == 'Niveau 3' && _selectedClassNodeId == null) {
      _showErrorSnackBar('La classe/série est obligatoire pour un exercice indépendant (Niveau 3).');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(supabaseServiceProvider);

      final statementMediaPayload = _statementMedia
          .map((a) => {'url': a.url, 'filename': a.filename, 'type': a.type})
          .toList();
      final solutionMediaPayload = _solutionMedia
          .map((a) => {'url': a.url, 'filename': a.filename, 'type': a.type})
          .toList();

      final options = _optionControllers
          .map((c) => c.text.trim())
          .where((o) => o.isNotEmpty)
          .toList();

      final hints = _hintsController.text
          .split('\n')
          .map((h) => h.trim())
          .where((h) => h.isNotEmpty)
          .toList();

      final skills = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final prerequisites = _prerequisitesController.text
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final instructionsJson = {
        'statement': _statementController.text.trim(),
        'media': statementMediaPayload,
        if (_selectedFormat == ExerciseFormat.qcm && options.isNotEmpty)
          'options': options,
        if (hints.isNotEmpty) 'hints': hints,
      };

      final solutionJson = {
        'correction': _solutionController.text.trim(),
        'media': solutionMediaPayload,
        if (_selectedFormat == ExerciseFormat.qcm && _correctOptionIndex != null)
          'correct_index': _correctOptionIndex,
      };

      // Déterminer le rattachement selon le niveau
      String? finalChapterId = _selectedChapterId;
      String? finalLessonId = _selectedLessonId;
      if (_selectedLevelTab == 'Niveau 3') {
        finalChapterId = null;
        finalLessonId = null;
      } else if (_selectedLevelTab == 'Niveau 2') {
        finalLessonId = null;
      }

      if (_currentExercise != null) {
        await service.updateExercise(
          id: _currentExercise!.id,
          title: title,
          type: _selectedType,
          difficulty: _selectedDifficulty,
          format: _selectedFormat,
          instructionsJson: instructionsJson,
          solutionJson: solutionJson,
          minSubscriptionTier: _selectedTier,
          updateLessonId: true,
          lessonId: finalLessonId,
          updateChapterId: true,
          chapterId: finalChapterId,
          updateClassNodeId: true,
          classNodeId: _selectedClassNodeId,
          updateTermId: true,
          termId: _selectedTermId,
          editedBy: _currentAdminId(),
          skills: skills,
          prerequisites: prerequisites,
        );

        if (publishNow && !_currentExercise!.isPublished) {
          await service.submitOrAutoApprove(
            contentId: _currentExercise!.id,
            contentType: 'exercise',
            authorId: _currentAdminId(),
            isSuperAdmin: ref.read(authProvider).valueOrNull?.isSuperAdmin ?? false,
          );
        }

        ref.invalidate(exercisesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exercice "$title" mis à jour avec succès.'),
              backgroundColor: AppTheme.accentEmerald,
            ),
          );
        }
      } else {
        final newExercise = await service.createExercise(
          lessonId: finalLessonId,
          chapterId: finalChapterId,
          classNodeId: _selectedClassNodeId,
          termId: _selectedTermId,
          type: _selectedType,
          difficulty: _selectedDifficulty,
          format: _selectedFormat,
          title: title,
          instructionsJson: instructionsJson,
          solutionJson: solutionJson,
          minSubscriptionTier: _selectedTier,
          skills: skills,
          prerequisites: prerequisites,
        );

        if (newExercise != null) {
          _currentExercise = newExercise;
          if (publishNow) {
            await service.submitOrAutoApprove(
              contentId: newExercise.id,
              contentType: 'exercise',
              authorId: _currentAdminId(),
              isSuperAdmin: ref.read(authProvider).valueOrNull?.isSuperAdmin ?? false,
            );
          }

          ref.invalidate(exercisesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exercice "$title" créé avec succès dans le Studio.'),
                backgroundColor: AppTheme.accentEmerald,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur d\'enregistrement : $e');
        _showErrorSnackBar('Erreur d\'enregistrement : $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRose,
      ),
    );
  }

  void _openInteractivePreview() {
    final statement = _statementController.text.trim().isEmpty
        ? _titleController.text.trim()
        : _statementController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    final explanation = _solutionController.text.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryBorder),
        ),
        title: AppDialogTitle(
          icon: Icons.preview_rounded,
          iconColor: AppTheme.accentCyan,
          text: 'Aperçu Élève (Rendu Interactif)',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      _buildLevelPillBadge(_selectedLevelTab),
                      const SizedBox(width: 8),
                      _buildTypeBadge(_selectedType),
                      const SizedBox(width: 8),
                      _buildDifficultyBadge(_selectedDifficulty),
                      const Spacer(),
                      Text(
                        _selectedTier.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Énoncé :',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MathText(
                        statement,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      if (options.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Options de réponse :',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...options.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final optText = entry.value;
                          final isCorrect = _correctOptionIndex == idx;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCorrect
                                    ? AppTheme.accentEmerald
                                    : AppTheme.primaryBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isCorrect
                                      ? AppTheme.accentEmerald
                                      : AppTheme.primaryBorder,
                                  child: Text(
                                    String.fromCharCode(65 + idx),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MathText(
                                    optText,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (isCorrect)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.accentEmerald,
                                    size: 18,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (explanation.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentEmerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb_rounded,
                                    size: 16,
                                    color: AppTheme.accentEmerald,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Explication / Corrigé :',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentEmerald,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              MathText(
                                explanation,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white,
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final classNodesAsync = ref.watch(nodesByTypeProvider('class'));
    final seriesNodesAsync = ref.watch(nodesByTypeProvider('series'));
    final classOptions = mergeClassOptions(
      classNodesAsync.valueOrNull ?? [],
      seriesNodesAsync.valueOrNull ?? [],
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Column(
        children: [
          // 1. Barre Supérieure (Top Studio Bar)
          _buildTopBar(),

          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.accentRose.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.accentRose, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(color: AppTheme.accentRose, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.accentRose, size: 18),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),

          // 2. Espace Studio : Double Volet Split-Workspace (Éditeur + Live Canvas) sur grand écran
          Expanded(
            child: MediaQuery.of(context).size.width >= 1050
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Volet Gauche : Éditeur d'Exercice (Flex 11)
                      Expanded(
                        flex: 11,
                        child: Column(
                          children: [
                            _buildTabBar(),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildStatementTab(),
                                  _buildCorrectionTab(),
                                  _buildMetadataTab(classOptions),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Séparateur vertical moderne
                      Container(
                        width: 1,
                        color: AppTheme.primaryBorder,
                      ),

                      // Volet Droit : Live Canvas Élève Interactif en Temps Réel (Flex 9)
                      Expanded(
                        flex: 9,
                        child: _buildLiveCanvas(),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStatementTab(),
                            _buildCorrectionTab(),
                            _buildMetadataTab(classOptions),
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

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primarySurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryBorder),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.accentCyan,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.edit_note_rounded, size: 18),
            text: '1. Énoncé & Médias',
          ),
          Tab(
            icon: Icon(Icons.checklist_rounded, size: 18),
            text: '2. Choix & Corrigé',
          ),
          Tab(
            icon: Icon(Icons.account_tree_rounded, size: 18),
            text: '3. Rattachement & Métadonnées',
          ),
        ],
      ),
    );
  }

  // --- Live Canvas Élève Interactif (Temps Réel) ---

  Widget _buildLiveCanvas() {
    final statementText = _statementController.text.trim();
    final solutionText = _solutionController.text.trim();
    final titleText = _titleController.text.trim().isEmpty
        ? 'Exercice sans titre'
        : _titleController.text.trim();

    final hints = _hintsController.text
        .split('\n')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    return Container(
      color: const Color(0xFF090D16),
      child: Column(
        children: [
          // En-tête du Canvas Studio
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.primarySurface,
              border: Border(
                bottom: BorderSide(color: AppTheme.primaryBorder),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CANVAS ÉLÈVE',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Direct',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                // Commutateur Mode Énoncé / Mode Corrigé
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _previewShowCorrection = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: !_previewShowCorrection
                                ? AppTheme.accentBlue.withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: !_previewShowCorrection
                                  ? AppTheme.accentBlue
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 14,
                                color: !_previewShowCorrection
                                    ? Colors.white
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mode Question',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: !_previewShowCorrection
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _previewShowCorrection = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _previewShowCorrection
                                ? AppTheme.accentEmerald.withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _previewShowCorrection
                                  ? AppTheme.accentEmerald
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.task_alt_rounded,
                                size: 14,
                                color: _previewShowCorrection
                                    ? Colors.white
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mode Corrigé',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _previewShowCorrection
                                      ? Colors.white
                                      : AppTheme.textMuted,
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
          ),

          // Zone d'affichage du Canvas (Scrolling propre et spacieux)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge de méta-données et typologie
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildCanvasChip(
                            label: _difficultyLabel(_selectedDifficulty),
                            color: _difficultyColor(_selectedDifficulty),
                            icon: Icons.speed_rounded,
                          ),
                          _buildCanvasChip(
                            label: _typeLabel(_selectedType),
                            color: AppTheme.accentBlue,
                            icon: Icons.category_rounded,
                          ),
                          _buildCanvasChip(
                            label: _formatLabel(_selectedFormat),
                            color: AppTheme.accentIndigo,
                            icon: Icons.format_shapes_rounded,
                          ),
                          _buildCanvasChip(
                            label: _selectedLevelTab,
                            color: AppTheme.accentCyan,
                            icon: Icons.account_tree_rounded,
                          ),
                          if (_selectedTier == 'premium')
                            _buildCanvasChip(
                              label: 'PREMIUM',
                              color: AppTheme.accentAmber,
                              icon: Icons.star_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Titre
                      Text(
                        titleText,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cadre de l'Énoncé
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primaryBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 18,
                                  color: AppTheme.accentCyan,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Énoncé du problème',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (statementText.isEmpty)
                              Text(
                                "L'énoncé de l'exercice apparaîtra ici au fur et à mesure de votre saisie, avec interprétation en direct des formules mathématiques LaTeX (ex: \$x^2 + 3x = 0\$)...",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textMuted,
                                  height: 1.5,
                                ),
                              )
                            else
                              MathText(
                                statementText,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.6,
                                ),
                              ),
                            if (_statementMedia.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _statementMedia.map((media) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryDark,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.primaryBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.attachment_rounded,
                                          size: 16,
                                          color: AppTheme.accentCyan,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          media.filename,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Zone Interactive des Réponses
                      if (_selectedFormat == ExerciseFormat.qcm)
                        _buildCanvasQcmSection()
                      else if (_selectedFormat == ExerciseFormat.reponseCourte)
                        _buildCanvasOpenEndedSection()
                      else
                        _buildCanvasOpenEndedSection(),

                      const SizedBox(height: 24),

                      // Section Indices Didactiques (simulateur d'aide tuteur)
                      if (hints.isNotEmpty)
                        _buildCanvasHintsSection(hints),

                      // Section Corrigé Détaillé (Mode Corrigé actif)
                      if (_previewShowCorrection) ...[
                        const SizedBox(height: 24),
                        _buildCanvasCorrectionSection(solutionText),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasQcmSection() {
    final optionLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.checklist_rounded,
              size: 18,
              color: AppTheme.accentCyan,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Choix de réponse (simulation interactive)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_optionControllers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Text(
              'Aucune option définie. Ajoutez des choix dans le volet 2.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...List.generate(_optionControllers.length, (index) {
            final optionText = _optionControllers[index].text.trim();
            final letter = index < optionLetters.length ? optionLetters[index] : '${index + 1}';
            final isSelected = _previewSelectedOptionIndex == index;
            final isCorrect = _correctOptionIndex == index;

            Color borderColor = AppTheme.primaryBorder;
            Color bgColor = AppTheme.primarySurface;
            Widget? statusIndicator;

            if (_previewShowCorrection) {
              if (isCorrect) {
                borderColor = AppTheme.accentEmerald;
                bgColor = AppTheme.accentEmerald.withValues(alpha: 0.12);
                statusIndicator = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accentEmerald),
                      const SizedBox(width: 4),
                      Text(
                        'Bonne réponse',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ],
                  ),
                );
              } else if (isSelected) {
                borderColor = AppTheme.accentRose;
                bgColor = AppTheme.accentRose.withValues(alpha: 0.10);
                statusIndicator = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel_rounded, size: 14, color: AppTheme.accentRose),
                      const SizedBox(width: 4),
                      Text(
                        'Choix sélectionné',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentRose,
                        ),
                      ),
                    ],
                  ),
                );
              }
            } else if (isSelected) {
              borderColor = AppTheme.accentBlue;
              bgColor = AppTheme.accentBlue.withValues(alpha: 0.15);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _previewSelectedOptionIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentBlue
                                : AppTheme.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentBlue
                                  : AppTheme.primaryBorder,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: optionText.isEmpty
                              ? Text(
                                  'Option $letter (vide)',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.textMuted,
                                  ),
                                )
                              : MathText(
                                  optionText,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                        ),
                        if (statusIndicator != null) ...[
                          const SizedBox(width: 12),
                          statusIndicator,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCanvasOpenEndedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: AppTheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Réponse attendue de l\'élève',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Zone de saisie libre pour l\'élève (simulateur actif)...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_outlined, size: 18, color: AppTheme.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasHintsSection(List<String> hints) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                size: 18,
                color: AppTheme.accentAmber,
              ),
              const SizedBox(width: 8),
              Text(
                'Indices Pédagogiques Progressifs (${hints.length})',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentAmber,
                ),
              ),
              const Spacer(),
              if (_previewRevealedHints < hints.length)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _previewRevealedHints++;
                    });
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 14),
                  label: Text('Révéler un indice ($_previewRevealedHints/${hints.length})'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentAmber,
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    setState(() {
                      _previewRevealedHints = 0;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    textStyle: GoogleFonts.inter(fontSize: 12),
                  ),
                  child: const Text('Masquer les indices'),
                ),
            ],
          ),
          if (_previewRevealedHints > 0) ...[
            const SizedBox(height: 12),
            ...List.generate(_previewRevealedHints, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indice ${i + 1} :',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hints[i],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvasCorrectionSection(String solutionText) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accentEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentEmerald.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppTheme.accentEmerald,
              ),
              const SizedBox(width: 8),
              Text(
                'Corrigé Didactique & Explication Détaillée',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (solutionText.isEmpty)
            Text(
              'Aucune explication ou corrigé saisi pour le moment.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMuted,
              ),
            )
          else
            MathText(
              solutionText,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1.6,
              ),
            ),
          if (_solutionMedia.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _solutionMedia.map((media) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attachment_rounded,
                        size: 16,
                        color: AppTheme.accentEmerald,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        media.filename,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _difficultyLabel(ExerciseDifficulty d) {
    switch (d) {
      case ExerciseDifficulty.facile:
        return 'Facile';
      case ExerciseDifficulty.intermediaire:
        return 'Intermédiaire';
      case ExerciseDifficulty.approfondissement:
        return 'Approfondissement';
    }
  }

  Color _difficultyColor(ExerciseDifficulty d) {
    switch (d) {
      case ExerciseDifficulty.facile:
        return AppTheme.accentEmerald;
      case ExerciseDifficulty.intermediaire:
        return AppTheme.accentAmber;
      case ExerciseDifficulty.approfondissement:
        return AppTheme.accentRose;
    }
  }

  String _typeLabel(ExerciseType t) {
    switch (t) {
      case ExerciseType.training:
        return 'Entraînement';
      case ExerciseType.evaluation:
        return 'Évaluation';
    }
  }

  String _formatLabel(ExerciseFormat f) {
    switch (f) {
      case ExerciseFormat.qcm:
        return 'QCM';
      case ExerciseFormat.reponseCourte:
        return 'Réponse courte';
      case ExerciseFormat.redaction:
        return 'Rédaction';
      case ExerciseFormat.manuscritScan:
        return 'Manuscrit scanné';
      case ExerciseFormat.flashcard:
        return 'Flashcard';
    }
  }

  // --- Composants d'Interface ---

  Widget _buildTopBar() {
    final isPublished = _currentExercise?.isPublished ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.primarySurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryBorder),
        ),
      ),
      child: Row(
        children: [
          // Bouton Retour
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: AppTheme.primaryBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(
              'Banque d\'exercices',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),

          // Titre & Studio Label
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AppTheme.accentCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Studio d\'Exercice',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPublished
                                  ? AppTheme.accentEmerald.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPublished ? 'PUBLIÉ' : 'BROUILLON',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPublished
                                    ? AppTheme.accentEmerald
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _titleController.text.trim().isEmpty
                            ? 'Nouvel exercice'
                            : _titleController.text.trim(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Boutons d'Action Studio
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openInteractivePreview,
                icon: const Icon(Icons.preview_rounded, size: 16),
                label: Text(
                  'Aperçu Élève',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isSaving ? null : () => _saveExercise(),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(
                  _isSaving ? 'Enregistrement...' : 'Enregistrer',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Volet 1 : Énoncé & Médias ---
  Widget _buildStatementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Titre de l'exercice
              Text(
                'Titre de l\'exercice *',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ex : Calcul de limites par encadrement...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Ligne 2 : Type, Format, Difficulté
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Format d\'exercice',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<ExerciseFormat>(
                          isExpanded: true,
                          initialValue: _selectedFormat,
                          dropdownColor: AppTheme.primarySurface,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.primarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primaryBorder),
                            ),
                          ),
                          items: ExerciseFormat.values.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Text(exerciseFormatToDb(f).toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedFormat = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type d\'évaluation',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<ExerciseType>(
                          isExpanded: true,
                          initialValue: _selectedType,
                          dropdownColor: AppTheme.primarySurface,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.primarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primaryBorder),
                            ),
                          ),
                          items: ExerciseType.values.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(exerciseTypeToDb(t)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedType = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Difficulté',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<ExerciseDifficulty>(
                          isExpanded: true,
                          initialValue: _selectedDifficulty,
                          dropdownColor: AppTheme.primarySurface,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.primarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primaryBorder),
                            ),
                          ),
                          items: ExerciseDifficulty.values.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(exerciseDifficultyToDb(d)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedDifficulty = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Ligne 3 : Énoncé complet avec aperçu mathématique
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Énoncé de l\'exercice (LaTeX supporté via \$... et \$\$...\$\$)',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ex: Soit \$f(x) = \\frac{1}{x}\$...',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _statementController,
                maxLines: 7,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Saisissez l\'énoncé complet de l\'exercice ici...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              // Rendu direct de l'énoncé si formule présente
              if (_statementController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded, size: 14, color: AppTheme.accentCyan),
                          const SizedBox(width: 6),
                          Text(
                            'Rendu en direct de l\'énoncé :',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MathText(
                        _statementController.text.trim(),
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Médias de l'énoncé
              Text(
                'Figures & Pièces jointes de l\'énoncé',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              MediaAttachmentPicker(
                initialAssets: _statementMedia,
                onChanged: (assets) => setState(() => _statementMedia = assets),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Volet 2 : Choix & Corrigé Pédagogique ---
  Widget _buildCorrectionTab() {
    final isQcm = _selectedFormat == ExerciseFormat.qcm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section QCM si format QCM
              if (isQcm) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Options de réponse (Cliquez sur la puce pour désigner la bonne réponse)',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentCyan,
                        side: const BorderSide(color: AppTheme.primaryBorder),
                      ),
                      onPressed: () {
                        setState(() {
                          _optionControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: Text('Ajouter une option', style: GoogleFonts.inter(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._optionControllers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ctrl = entry.value;
                  final isCorrect = _correctOptionIndex == idx;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCorrect ? AppTheme.accentEmerald : AppTheme.primaryBorder,
                        width: isCorrect ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _correctOptionIndex = idx),
                          borderRadius: BorderRadius.circular(16),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: isCorrect
                                ? AppTheme.accentEmerald
                                : AppTheme.primaryBorder,
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Option ${String.fromCharCode(65 + idx)}...',
                              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (isCorrect)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CORRECT',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                          ),
                        if (_optionControllers.length > 2)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRose, size: 18),
                            tooltip: 'Supprimer cette option',
                            onPressed: () {
                              setState(() {
                                _optionControllers.removeAt(idx);
                                if (_correctOptionIndex == idx) {
                                  _correctOptionIndex = 0;
                                } else if (_correctOptionIndex != null && _correctOptionIndex! > idx) {
                                  _correctOptionIndex = _correctOptionIndex! - 1;
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Corrigé détaillé
              Text(
                'Corrigé détaillé / Démonstration pas à pas',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _solutionController,
                maxLines: 6,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Explication pédagogique complète...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Médias du corrigé
              Text(
                'Pièces jointes / Figures du corrigé',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              MediaAttachmentPicker(
                initialAssets: _solutionMedia,
                onChanged: (assets) => setState(() => _solutionMedia = assets),
              ),
              const SizedBox(height: 24),

              // Indices progressifs
              Text(
                'Indices progressifs (un par ligne)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aidez l\'élève sans lui donner la réponse directement.',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hintsController,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Indice 1 : Pensez à factoriser...\nIndice 2 : Appliquez le théorème...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Volet 3 : Rattachement & Métadonnées ---
  Widget _buildMetadataTab(List<AcademicNode> classOptions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélecteur des 3 Niveaux d'indépendance
              Text(
                'Niveau d\'indépendance pédagogique *',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildLevelChoiceCard(
                      title: 'Niveau 1 : Leçon précise',
                      description: 'Exercice d\'application directe rattaché à une leçon spécifique.',
                      icon: Icons.menu_book_rounded,
                      color: AppTheme.accentCyan,
                      isSelected: _selectedLevelTab == 'Niveau 1',
                      onTap: () => setState(() => _selectedLevelTab = 'Niveau 1'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLevelChoiceCard(
                      title: 'Niveau 2 : Chapitre général',
                      description: 'Exercice de synthèse couvrant l\'ensemble du chapitre.',
                      icon: Icons.folder_copy_rounded,
                      color: AppTheme.accentIndigo,
                      isSelected: _selectedLevelTab == 'Niveau 2',
                      onTap: () => setState(() => _selectedLevelTab = 'Niveau 2'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLevelChoiceCard(
                      title: 'Niveau 3 : Type Examen',
                      description: 'Exercice indépendant et autonome pour examen / concours.',
                      icon: Icons.school_rounded,
                      color: AppTheme.accentAmber,
                      isSelected: _selectedLevelTab == 'Niveau 3',
                      onTap: () => setState(() => _selectedLevelTab = 'Niveau 3'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sélecteur de Classe / Série
              Text(
                'Classe / Série cible *',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _selectedClassNodeId,
                dropdownColor: AppTheme.primarySurface,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Toutes les classes / Non rattaché'),
                  ),
                  ...classOptions.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                  if (_selectedClassNodeId != null &&
                      !classOptions.any((c) => c.id == _selectedClassNodeId))
                    DropdownMenuItem<String?>(
                      value: _selectedClassNodeId,
                      child: Text('Classe sélectionnée ($_selectedClassNodeId)'),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedClassNodeId = v),
              ),
              const SizedBox(height: 20),

              // Formule d'abonnement requise
              Text(
                'Formule d\'accès minimale',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedTier,
                dropdownColor: AppTheme.primarySurface,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'gratuit', child: Text('Gratuit (Accessible à tous)')),
                  DropdownMenuItem(value: 'journalier', child: Text('Pass Journalier')),
                  DropdownMenuItem(value: 'mensuel', child: Text('Abonnement Premium')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedTier = v);
                },
              ),
              const SizedBox(height: 20),

              // Compétences & Prérequis
              Text(
                'Compétences mobilisées (séparées par des virgules)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _skillsController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ex: dérivation, limites, trigo...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Prérequis académiques (séparés par des virgules)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _prerequisitesController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ex: calcul littéral, équations du 2nd degré...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelChoiceCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.primaryBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelPillBadge(String level) {
    Color color = AppTheme.accentCyan;
    if (level.contains('2')) color = AppTheme.accentIndigo;
    if (level.contains('3')) color = AppTheme.accentAmber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildTypeBadge(ExerciseType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentIndigo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        exerciseTypeToDb(type),
        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentIndigo),
      ),
    );
  }

  Widget _buildDifficultyBadge(ExerciseDifficulty difficulty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        exerciseDifficultyToDb(difficulty),
        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentPurple),
      ),
    );
  }
}
