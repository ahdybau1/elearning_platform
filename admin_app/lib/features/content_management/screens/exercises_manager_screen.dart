import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../utils/exercise_pdf_generator.dart';
import '../../../core/widgets/app_dialog_title.dart';
import 'exercise_ai_generation_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_student_preview_screen.dart';
import 'exercise_studio_screen.dart';

/// Sentinelle pour filtre "exercices non classés"
const _unclassedFilterSentinel = '__non_classe__';

enum ExerciseHubTab {
  curriculum, // Niveaux 1 & 2 : Exercices rattachés au programme
  exams, // Niveau 3 : Épreuves d'examens et concours indépendants
}

/// Écran principal de la Banque d'Exercices — Hub aéré et structuré en espaces dédiés.
///
/// Fin du tout-en-un touffu et des inspecteurs imbriqués :
/// 1. Séparation nette entre **Exercices du Programme** et **Examens & Concours**.
/// 2. Navigation contextuelle par Classe et Matière pour retrouver immédiatement ses chapitres.
/// 3. Fiches d'exercices légères et respirantes avec consultation directe en plein écran ([ExerciseDetailScreen]).
class ExercisesManagerScreen extends ConsumerStatefulWidget {
  const ExercisesManagerScreen({super.key});

  @override
  ConsumerState<ExercisesManagerScreen> createState() =>
      _ExercisesManagerScreenState();
}

class _ExercisesManagerScreenState
    extends ConsumerState<ExercisesManagerScreen> {
  ExerciseHubTab _activeTab = ExerciseHubTab.curriculum;

  String? _selectedClassFilterId;
  String? _selectedSubjectFilterId;
  bool _showInactive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _currentAdminId() {
    return ref.read(authProvider).valueOrNull?.id ??
        '00000000-0000-0000-0000-000000000001';
  }

  void _openExerciseDetail(Exercise ex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(initialExercise: ex),
      ),
    ).then((_) {
      ref.invalidate(exercisesProvider);
    });
  }

  void _openStudio({Exercise? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseStudioScreen(
          exerciseId: existing?.id,
          existingExercise: existing,
        ),
      ),
    ).then((_) {
      ref.invalidate(exercisesProvider);
    });
  }

  void _openAiGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseAiGenerationScreen(
          initialClassNodeId: _selectedClassFilterId,
        ),
      ),
    ).then((_) {
      ref.invalidate(exercisesProvider);
    });
  }

  void _openStudentPreview(Exercise ex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseStudentPreviewScreen(exercise: ex),
      ),
    );
  }

  Future<void> _printExercise(Exercise ex) async {
    final service = ref.read(supabaseServiceProvider);
    String subjectName = 'Matière';
    String? chapterTitle;
    if (ex.chapterId != null) {
      final chapter = await service.getChapter(ex.chapterId!);
      if (chapter != null) {
        chapterTitle = chapter.title;
        final subject = await service.getSubject(chapter.subjectId);
        if (subject != null) subjectName = subject.name;
      }
    }
    await ExercisePdfGenerator.printOrSave(
      exercise: ex,
      subjectName: subjectName,
      chapterTitle: chapterTitle,
    );
  }

  Future<void> _reorderExercise(Exercise ex, List<Exercise> siblings, int delta) async {
    final idx = siblings.indexWhere((e) => e.id == ex.id);
    final target = idx + delta;
    if (idx < 0 || target < 0 || target >= siblings.length) return;
    final other = siblings[target];
    try {
      await ref.read(supabaseServiceProvider).swapExerciseOrder(
        ex.id,
        ex.displayOrder,
        other.id,
        other.displayOrder,
      );
      ref.invalidate(exercisesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réorganisation: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider(_showInactive));
    final classNodesAsync = ref.watch(nodesByTypeProvider('class'));
    final seriesNodesAsync = ref.watch(nodesByTypeProvider('series'));
    final classOptions = mergeClassOptions(
      classNodesAsync.valueOrNull ?? [],
      seriesNodesAsync.valueOrNull ?? [],
    );

    final allExercises = exercisesAsync.valueOrNull ?? <Exercise>[];
    final curriculumCount = allExercises
        .where((e) => e.lessonId != null || e.chapterId != null)
        .length;
    final examCount = allExercises
        .where((e) => e.lessonId == null && e.chapterId == null)
        .length;

    return Material(
      color: AppTheme.primaryDark,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête Spacieux & Actions Nobles
            _buildHeader(),
            const SizedBox(height: 18),

            // Sélecteur des 2 Espaces Dédiés (Pilules Supérieures)
            _buildHubTabs(curriculumCount: curriculumCount, examCount: examCount),
            const SizedBox(height: 16),

            // Barre de Filtres Contextuelle Aérée
            _buildFilterBar(classOptions),
            const SizedBox(height: 18),

            // Zone Principale de Contenu
            Expanded(
              child: exercisesAsync.when(
                data: (exercises) {
                  return _buildContentList(exercises, classOptions);
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.accentRose),
                      const SizedBox(height: 10),
                      Text(
                        'Erreur de chargement: $err',
                        style: GoogleFonts.inter(color: AppTheme.accentRose),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => ref.invalidate(exercisesProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        final titleArea = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_rounded,
                color: AppTheme.accentIndigo,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Banque d\'Exercices',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Évaluation et entraînement pédagogique structuré en 3 niveaux d\'indépendance (Leçon, Chapitre, Examen)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openAiGenerator,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                'Générateur IA',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openStudio(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                '+ Nouvel Exercice (Studio)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleArea,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleArea),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHubTabs({required int curriculumCount, required int examCount}) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(
              tab: ExerciseHubTab.curriculum,
              label: 'Exercices du Programme (Niveaux 1 & 2)',
              count: curriculumCount,
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(width: 6),
            _buildTabItem(
              tab: ExerciseHubTab.exams,
              label: 'Examens & Concours (Niveau 3)',
              count: examCount,
              icon: Icons.school_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required ExerciseHubTab tab,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tab;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentCyan.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : Colors.transparent,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentCyan.withValues(alpha: 0.25)
                    : AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.accentCyan : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<AcademicNode> classOptions) {
    final isFiltered = _searchQuery.isNotEmpty ||
        _selectedClassFilterId != null ||
        _selectedSubjectFilterId != null;

    final searchField = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Rechercher un exercice par titre ou notion...',
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textMuted,
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Effacer la recherche',
                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );

    final classDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: DropdownButtonFormField<String?>(
        initialValue: _selectedClassFilterId,
        isDense: true,
        isExpanded: true,
        dropdownColor: AppTheme.primaryDark,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixIcon: Icon(Icons.school_outlined, color: AppTheme.textMuted, size: 18),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Toutes les classes'),
          ),
          const DropdownMenuItem<String?>(
            value: _unclassedFilterSentinel,
            child: Text('Non classé'),
          ),
          ...classOptions.map(
            (c) => DropdownMenuItem<String?>(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _selectedClassFilterId = v;
            _selectedSubjectFilterId = null;
          });
        },
      ),
    );

    final archiveToggle = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: _showInactive,
            activeThumbColor: AppTheme.accentAmber,
            onChanged: (v) => setState(() => _showInactive = v),
          ),
          Text(
            'Archives',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    final resetBtn = isFiltered
        ? TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedClassFilterId = null;
                _selectedSubjectFilterId = null;
              });
            },
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: AppTheme.accentRose),
            label: Text(
              'Réinitialiser',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose),
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: classDropdown),
                  const SizedBox(width: 12),
                  archiveToggle,
                  if (resetBtn != null) ...[
                    const SizedBox(width: 8),
                    resetBtn,
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            SizedBox(width: 210, child: classDropdown),
            const SizedBox(width: 12),
            archiveToggle,
            if (resetBtn != null) ...[
              const SizedBox(width: 8),
              resetBtn,
            ],
          ],
        );
      },
    );
  }

  Widget _buildContentList(List<Exercise> allExercises, List<AcademicNode> classOptions) {
    // 1. Filtrer par recherche et classe
    var filtered = allExercises.where((e) {
      if (_searchQuery.isNotEmpty && !e.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_selectedClassFilterId == _unclassedFilterSentinel && e.classNodeId != null) {
        return false;
      }
      if (_selectedClassFilterId != null &&
          _selectedClassFilterId != _unclassedFilterSentinel &&
          e.classNodeId != _selectedClassFilterId) {
        return false;
      }
      return true;
    }).toList();

    // 2. Filtrer par onglet actif
    if (_activeTab == ExerciseHubTab.curriculum) {
      // Niveaux 1 et 2
      filtered = filtered
          .where((e) => e.lessonId != null || e.chapterId != null)
          .toList();
    } else {
      // Niveau 3 (Examens / indépendants)
      filtered = filtered
          .where((e) => e.lessonId == null && e.chapterId == null)
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryBorder),
                ),
                child: const Icon(Icons.quiz_outlined, size: 48, color: AppTheme.accentCyan),
              ),
              const SizedBox(height: 18),
              Text(
                'Aucun exercice trouvé dans cette section',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty || _selectedClassFilterId != null
                    ? 'Aucun exercice ne correspond à vos critères de recherche.'
                    : (_activeTab == ExerciseHubTab.curriculum
                        ? 'Créez votre premier exercice de cours ou générez-en un avec l\'IA.'
                        : 'Aucune épreuve d\'examen ou de concours indépendant enregistrée.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openStudio(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('+ Créer un exercice'),
              ),
            ],
          ),
        ),
      );
    }

    // Regrouper par Chapitre si dans l'onglet Curriculum
    if (_activeTab == ExerciseHubTab.curriculum) {
      return _buildCurriculumGroupedList(filtered, classOptions);
    }

    // Afficher en grille / liste aérée si Examens
    return _buildExamsList(filtered, classOptions);
  }

  Widget _buildCurriculumGroupedList(List<Exercise> exercises, List<AcademicNode> classOptions) {
    // Regrouper par chapterId
    final Map<String?, List<Exercise>> grouped = {};
    for (final ex in exercises) {
      grouped.putIfAbsent(ex.chapterId, () => []).add(ex);
    }

    final chapterEntries = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: chapterEntries.length,
      itemBuilder: (context, index) {
        final entry = chapterEntries[index];
        final chapterId = entry.key;
        final chapterExercises = entry.value;

        return _ChapterExercisesFolder(
          chapterId: chapterId,
          exercises: chapterExercises,
          classOptions: classOptions,
          onOpenDetail: _openExerciseDetail,
          onOpenStudio: (ex) => _openStudio(existing: ex),
          onOpenPreview: _openStudentPreview,
          onExportPdf: _printExercise,
          onReorder: _reorderExercise,
          onDelete: (ex) => _showDeactivateExerciseConfirmation(context, ex),
          onDuplicate: (ex) {
            ref.read(supabaseServiceProvider).duplicateExercise(ex.id, _currentAdminId()).then((_) {
              ref.invalidate(exercisesProvider);
            });
          },
        );
      },
    );
  }

  Widget _buildExamsList(List<Exercise> exercises, List<AcademicNode> classOptions) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: exercises.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ex = exercises[index];
        return _CleanExerciseCard(
          exercise: ex,
          classOptions: classOptions,
          siblings: exercises,
          onTap: () => _openExerciseDetail(ex),
          onOpenStudio: () => _openStudio(existing: ex),
          onOpenPreview: () => _openStudentPreview(ex),
          onExportPdf: () => _printExercise(ex),
          onReorder: (delta) => _reorderExercise(ex, exercises, delta),
          onDelete: () => _showDeactivateExerciseConfirmation(context, ex),
          onDuplicate: () {
            ref.read(supabaseServiceProvider).duplicateExercise(ex.id, _currentAdminId()).then((_) {
              ref.invalidate(exercisesProvider);
            });
          },
        );
      },
    );
  }

  void _showDeactivateExerciseConfirmation(BuildContext context, Exercise ex) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.archive_rounded,
      iconColor: AppTheme.accentAmber,
      title: 'Archiver "${ex.title}" ?',
      content: Text(
        'Cet exercice sera masqué aux élèves, pas supprimé — vous pourrez le désarchiver plus tard.',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
      ),
      confirmLabel: 'Archiver',
      confirmColor: AppTheme.accentAmber,
      onConfirm: () => service.updateExercise(id: ex.id, isActive: false),
      successMessage: 'Exercice archivé.',
    );
  }

  void _showConfirmActionDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
    required String successMessage,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: icon,
          iconColor: iconColor,
          text: title,
          onClose: () => Navigator.pop(ctx),
        ),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await onConfirm();
              ref.invalidate(exercisesProvider);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(successMessage), backgroundColor: AppTheme.accentEmerald),
                );
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

/// Dossier de Chapitre affichant ses exercices rattachés de façon aérée.
class _ChapterExercisesFolder extends ConsumerWidget {
  final String? chapterId;
  final List<Exercise> exercises;
  final List<AcademicNode> classOptions;
  final void Function(Exercise) onOpenDetail;
  final void Function(Exercise) onOpenStudio;
  final void Function(Exercise) onOpenPreview;
  final void Function(Exercise) onExportPdf;
  final Future<void> Function(Exercise, List<Exercise>, int) onReorder;
  final void Function(Exercise) onDelete;
  final void Function(Exercise) onDuplicate;

  const _ChapterExercisesFolder({
    required this.chapterId,
    required this.exercises,
    required this.classOptions,
    required this.onOpenDetail,
    required this.onOpenStudio,
    required this.onOpenPreview,
    required this.onExportPdf,
    required this.onReorder,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(supabaseServiceProvider);

    return FutureBuilder<Chapter?>(
      future: chapterId != null ? service.getChapter(chapterId!) : Future.value(null),
      builder: (context, snapshot) {
        final chapterTitle = snapshot.data?.title ??
            (chapterId == null ? 'Exercices sans chapitre rattaché' : 'Chapitre');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: Material(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_copy_rounded, color: AppTheme.accentCyan, size: 20),
                ),
                title: Text(
                  chapterTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '${exercises.length} exercice${exercises.length > 1 ? 's' : ''} d\'évaluation et d\'entraînement',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: List.generate(exercises.length, (i) {
                        final ex = exercises[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CleanExerciseCard(
                            exercise: ex,
                            classOptions: classOptions,
                            siblings: exercises,
                            onTap: () => onOpenDetail(ex),
                            onOpenStudio: () => onOpenStudio(ex),
                            onOpenPreview: () => onOpenPreview(ex),
                            onExportPdf: () => onExportPdf(ex),
                            onReorder: (delta) => onReorder(ex, exercises, delta),
                            onDelete: () => onDelete(ex),
                            onDuplicate: () => onDuplicate(ex),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Carte d'exercice épurée, noble et respirante.
///
/// Un clic franc sur la carte ouvre immédiatement la fiche détaillée en plein écran.
class _CleanExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final List<AcademicNode> classOptions;
  final List<Exercise> siblings;
  final VoidCallback onTap;
  final VoidCallback onOpenStudio;
  final VoidCallback onOpenPreview;
  final VoidCallback onExportPdf;
  final void Function(int delta) onReorder;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _CleanExerciseCard({
    required this.exercise,
    required this.classOptions,
    required this.siblings,
    required this.onTap,
    required this.onOpenStudio,
    required this.onOpenPreview,
    required this.onExportPdf,
    required this.onReorder,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    final idx = siblings.indexWhere((e) => e.id == ex.id);
    final canReorder = siblings.length > 1 && idx >= 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ex.isActive
                  ? AppTheme.primaryBorder
                  : AppTheme.accentAmber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              // Icône du format didactique
              _buildFormatIcon(ex.format),
              const SizedBox(width: 14),

              // Informations principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge(exerciseTypeToDb(ex.type), AppTheme.accentEmerald),
                        _buildBadge(exerciseFormatToDb(ex.format), AppTheme.accentIndigo),
                        _buildBadge(exerciseDifficultyToDb(ex.difficulty), AppTheme.accentCyan),
                        _buildBadge(
                          ex.isPublished ? 'PUBLIÉ' : 'BROUILLON',
                          ex.isPublished ? AppTheme.accentEmerald : AppTheme.accentAmber,
                        ),
                        if (!ex.isActive)
                          _buildBadge('ARCHIVÉ', AppTheme.accentAmber),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Raccourcis d'ordonnancement (▲/▼)
              if (canReorder) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white54),
                  tooltip: 'Monter',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: idx == 0 ? null : () => onReorder(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white54),
                  tooltip: 'Descendre',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: idx == siblings.length - 1 ? null : () => onReorder(1),
                ),
                const SizedBox(width: 8),
              ],

              // Bouton d'ouverture / inspection principale
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.accentCyan,
                  elevation: 0,
                  side: const BorderSide(color: AppTheme.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onTap,
                icon: const Icon(Icons.visibility_rounded, size: 15),
                label: Text(
                  'Consulter',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // Bouton Aperçu direct
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onOpenPreview,
                icon: const Icon(Icons.preview_rounded, size: 15),
                label: Text(
                  'Aperçu',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // Menu contextuel discret
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
                color: AppTheme.primarySurface,
                onSelected: (val) {
                  if (val == 'studio') onOpenStudio();
                  if (val == 'preview') onOpenPreview();
                  if (val == 'pdf') onExportPdf();
                  if (val == 'duplicate') onDuplicate();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'studio',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.accentIndigo),
                        SizedBox(width: 8),
                        Text('Modifier (Studio)', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'preview',
                    child: Row(
                      children: [
                        Icon(Icons.preview_rounded, size: 16, color: AppTheme.accentCyan),
                        SizedBox(width: 8),
                        Text('Aperçu Élève', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppTheme.accentRose),
                        SizedBox(width: 8),
                        Text('Exporter PDF', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 16, color: AppTheme.accentEmerald),
                        SizedBox(width: 8),
                        Text('Dupliquer', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.archive_rounded, size: 16, color: AppTheme.accentAmber),
                        SizedBox(width: 8),
                        Text('Archiver', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatIcon(ExerciseFormat format) {
    IconData icon;
    Color color;

    switch (format) {
      case ExerciseFormat.qcm:
        icon = Icons.check_box_outlined;
        color = AppTheme.accentCyan;
        break;
      case ExerciseFormat.reponseCourte:
        icon = Icons.short_text_rounded;
        color = AppTheme.accentEmerald;
        break;
      case ExerciseFormat.redaction:
        icon = Icons.article_outlined;
        color = AppTheme.accentIndigo;
        break;
      case ExerciseFormat.manuscritScan:
        icon = Icons.document_scanner_rounded;
        color = AppTheme.accentAmber;
        break;
      case ExerciseFormat.flashcard:
        icon = Icons.style_rounded;
        color = AppTheme.accentRose;
        break;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
