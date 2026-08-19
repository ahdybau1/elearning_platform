import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../widgets/media_attachment_picker.dart';
import '../utils/exercise_pdf_generator.dart';
import '../../../core/widgets/app_dialog_title.dart';

/// Filtre "exercices non classés" (class_node_id NULL) — sentinelle distincte de `null` (qui
/// signifie "toutes les classes") pour le filtre Classe de la barre de recherche.
const _unclassedFilterSentinel = '__non_classe__';

class ExercisesManagerScreen extends ConsumerStatefulWidget {
  const ExercisesManagerScreen({super.key});

  @override
  ConsumerState<ExercisesManagerScreen> createState() =>
      _ExercisesManagerScreenState();
}

class _ExercisesManagerScreenState
    extends ConsumerState<ExercisesManagerScreen> {
  String _selectedLevelFilter = 'Tous les niveaux';
  String? _selectedClassFilterId;
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

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider(_showInactive));
    final classNodesAsync = ref.watch(nodesByTypeProvider('class'));
    final seriesNodesAsync = ref.watch(nodesByTypeProvider('series'));
    final classOptions = <AcademicNode>[
      ...classNodesAsync.valueOrNull ?? [],
      ...seriesNodesAsync.valueOrNull ?? [],
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & Action bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banque d\'Exercices Pédagogiques',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Structure à 3 niveaux d\'indépendance (Leçon, Chapitre, Indépendant type examen)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                    onPressed: () => _showAiGenerationModal(context),
                    icon: const Icon(Icons.psychology_rounded, size: 18),
                    label: const Text('Générer par IA'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateExerciseModal(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Créer un Exercice'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Independence Level Tabs
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildLevelTab('Tous les niveaux'),
              _buildLevelTab('Niveau 1 : Leçon précise'),
              _buildLevelTab('Niveau 2 : Chapitre général'),
              _buildLevelTab('Niveau 3 : Indépendant (Type Examen)'),
            ],
          ),
          const SizedBox(height: 16),

          // Filters : recherche + classe + archives
          Row(
            children: [
              Expanded(
                child: Container(
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
                      hintText: 'Rechercher un exercice par titre...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  // ignore: deprecated_member_use
                  child: DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _selectedClassFilterId,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: AppTheme.primaryDark,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Toutes les classes')),
                      const DropdownMenuItem<String?>(value: _unclassedFilterSentinel, child: Text('Non classé')),
                      ...classOptions.map((c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedClassFilterId = v),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Switch(
                    value: _showInactive,
                    activeThumbColor: AppTheme.accentAmber,
                    onChanged: (v) => setState(() => _showInactive = v),
                  ),
                  Text('Afficher les archives',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Exercices — dossiers par Trimestre (même hiérarchie que Chapitres & Leçons), au lieu
          // d'une simple grille plate.
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                final filtered = _filterExercises(exercises)
                    .where((e) => _searchQuery.isEmpty || e.title.toLowerCase().contains(_searchQuery))
                    .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun exercice trouvé. Créez un nouvel exercice ou utilisez la génération IA.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  );
                }
                return Consumer(
                  builder: (context, ref, _) {
                    final termsAsync = ref.watch(termsProvider(null));
                    final terms = List<Term>.from(termsAsync.valueOrNull ?? <Term>[])
                      ..sort((a, b) => a.startDate.compareTo(b.startDate));
                    final byTerm = <String?, List<Exercise>>{};
                    for (final e in filtered) {
                      byTerm.putIfAbsent(e.termId, () => []).add(e);
                    }
                    final orderedTermIds = <String?>[
                      ...terms.map((t) => t.id).where(byTerm.containsKey),
                      if (byTerm.containsKey(null)) null,
                    ];
                    return ListView.builder(
                      itemCount: orderedTermIds.length,
                      itemBuilder: (context, idx) {
                        final termId = orderedTermIds[idx];
                        final term = terms.where((t) => t.id == termId).firstOrNull;
                        return _buildTermFolder(term, byTerm[termId]!, classOptions);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Erreur: $err',
                  style: GoogleFonts.inter(color: AppTheme.accentRose),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dossier "Trimestre" regroupant les exercices qui y sont rattachés (directement pour les
  /// indépendants Niveau 3, hérité du chapitre/leçon pour Niveau 1/2) — même hiérarchie que
  /// _buildTermFolder dans lessons_manager_screen.dart, pour une organisation cohérente entre les
  /// deux écrans plutôt qu'une grille plate sans classement.
  Widget _buildTermFolder(Term? term, List<Exercise> exercises, List<AcademicNode> classOptions) {
    final folderLabel = term == null ? 'Sans trimestre assigné' : '${term.name} — Année ${term.schoolYear}';
    final independentExercises =
        exercises.where((e) => e.chapterId == null && e.lessonId == null).toList();
    final linkedExercises = exercises.where((e) => e.chapterId != null || e.lessonId != null).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: term == null ? AppTheme.accentAmber.withValues(alpha: 0.3) : AppTheme.accentIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('ex-term-${term?.id ?? 'none'}'),
          initiallyExpanded: true,
          backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.3),
          collapsedBackgroundColor: AppTheme.primaryDark.withValues(alpha: 0.3),
          leading: Icon(
            term == null ? Icons.folder_off_rounded : Icons.folder_rounded,
            color: term == null ? AppTheme.accentAmber : AppTheme.accentIndigo,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  folderLabel,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: term == null ? AppTheme.accentAmber : Colors.white,
                  ),
                ),
              ),
              Text('${exercises.length} exercice(s)', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (linkedExercises.isNotEmpty) ...[
                    Text('Rattachés à un chapitre/leçon',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.0,
                      ),
                      itemCount: linkedExercises.length,
                      itemBuilder: (context, idx) => _buildExerciseCard(linkedExercises[idx], classOptions),
                    ),
                    if (independentExercises.isNotEmpty) const SizedBox(height: 20),
                  ],
                  if (independentExercises.isNotEmpty) ...[
                    Text('Indépendants (type examen)',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.0,
                      ),
                      itemCount: independentExercises.length,
                      itemBuilder: (context, idx) => _buildExerciseCard(independentExercises[idx], classOptions),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Exercise> _filterExercises(List<Exercise> exercises) {
    var result = exercises;
    if (_selectedLevelFilter.contains('Leçon précise')) {
      result = result.where((e) => e.lessonId != null).toList();
    } else if (_selectedLevelFilter.contains('Chapitre général')) {
      result = result
          .where((e) => e.chapterId != null && e.lessonId == null)
          .toList();
    } else if (_selectedLevelFilter.contains('Indépendant')) {
      result = result
          .where((e) => e.lessonId == null && e.chapterId == null)
          .toList();
    }
    if (_selectedClassFilterId == _unclassedFilterSentinel) {
      result = result.where((e) => e.classNodeId == null).toList();
    } else if (_selectedClassFilterId != null) {
      result = result.where((e) => e.classNodeId == _selectedClassFilterId).toList();
    }
    return result;
  }

  Widget _buildExerciseCard(Exercise ex, List<AcademicNode> classOptions) {
    final typeLabel = exerciseTypeToDb(ex.type);
    final formatLabel = exerciseFormatToDb(ex.format);
    final difficultyLabel = exerciseDifficultyToDb(ex.difficulty);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ex.isActive ? AppTheme.primaryBorder : AppTheme.accentAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildContextChip(ex)),
              const SizedBox(width: 8),
              Row(
                children: [
                  if (!ex.isActive)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('ARCHIVÉ',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppTheme.accentAmber, fontWeight: FontWeight.bold)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (ex.isPublished ? AppTheme.accentEmerald : Colors.white)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ex.isPublished ? 'Publié' : 'Brouillon',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: ex.isPublished ? AppTheme.accentEmerald : Colors.white60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ex.minSubscriptionTier,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.accentAmber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            ex.title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildClassBadge(ex, classOptions),
                    _buildBadge(typeLabel, AppTheme.accentEmerald),
                    _buildBadge(formatLabel, AppTheme.accentIndigo),
                    _buildBadge(difficultyLabel, AppTheme.accentCyan),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppTheme.accentRose),
                tooltip: 'Imprimer / Exporter en PDF',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _printExercise(ex),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, size: 18, color: AppTheme.accentCyan),
                tooltip: 'Historique des versions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _showVersionHistoryModal(context, ex),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                tooltip: 'Modifier',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _showCreateExerciseModal(context, existing: ex),
              ),
              IconButton(
                icon: Icon(
                  ex.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
                  size: 18,
                  color: AppTheme.accentAmber,
                ),
                tooltip: ex.isActive ? 'Archiver' : 'Désarchiver',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => ex.isActive
                    ? _showDeactivateExerciseConfirmation(context, ex)
                    : _showReactivateExerciseConfirmation(context, ex),
              ),
              if (!ex.isActive)
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppTheme.accentRose),
                  tooltip: 'Supprimer définitivement',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _showPermanentDeleteExerciseConfirmation(context, ex),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Titre réel du chapitre/leçon rattaché(e), résolu à la volée (léger, une seule ligne à la
  /// fois) plutôt que d'afficher l'UUID brut tronqué comme auparavant.
  Widget _buildContextChip(Exercise ex) {
    if (ex.chapterId == null && ex.lessonId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Text('Indépendant',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
      );
    }
    final service = ref.read(supabaseServiceProvider);
    return FutureBuilder<String>(
      future: ex.lessonId != null
          ? service.getLesson(ex.lessonId!).then((l) => l != null ? 'Leçon : ${l.title}' : 'Leçon introuvable')
          : service.getChapter(ex.chapterId!).then((c) => c != null ? 'Chapitre : ${c.title}' : 'Chapitre introuvable'),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: Text(
            snapshot.data ?? '…',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentBlue, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  /// Dialogue de confirmation générique pour archiver/désarchiver/supprimer définitivement un
  /// exercice — même pattern que celui de lessons_manager_screen.dart (dupliqué plutôt que
  /// partagé : ce sont deux State privées de fichiers différents, pas d'endroit commun évident
  /// pour ce widget sans élargir sa portée au-delà de ce qui est nécessaire ici).
  Future<void> _showConfirmActionDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
    required String successMessage,
    String? typedConfirmationTarget,
  }) async {
    bool isLoading = false;
    String? errorText;
    final typedController = TextEditingController();
    bool matches = typedConfirmationTarget == null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(icon: icon, iconColor: iconColor, text: title, onClose: () => Navigator.pop(ctx)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  if (typedConfirmationTarget != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tapez "$typedConfirmationTarget" pour confirmer :',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: typedController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: typedConfirmationTarget,
                        prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                      ),
                      onChanged: (v) => setModalState(() => matches = v.trim() == typedConfirmationTarget),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.accentRose, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(errorText!,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
              onPressed: (isLoading || !matches)
                  ? null
                  : () async {
                      setModalState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await onConfirm();
                        ref.invalidate(exercisesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text(successMessage)),
                        );
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(confirmLabel),
            ),
          ],
        ),
      ),
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
        'Cet exercice sera masqué aux élèves, pas supprimé — vous pourrez le désarchiver ou le '
        'supprimer définitivement plus tard.',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
      ),
      confirmLabel: 'Archiver',
      confirmColor: AppTheme.accentAmber,
      onConfirm: () => service.updateExercise(id: ex.id, isActive: false),
      successMessage: 'Exercice "${ex.title}" archivé.',
    );
  }

  void _showReactivateExerciseConfirmation(BuildContext context, Exercise ex) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.unarchive_rounded,
      iconColor: AppTheme.accentEmerald,
      title: 'Désarchiver "${ex.title}" ?',
      content: Text(
        'Cet exercice redeviendra actif et visible dans l\'application.',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
      ),
      confirmLabel: 'Désarchiver',
      confirmColor: AppTheme.accentEmerald,
      onConfirm: () => service.updateExercise(id: ex.id, isActive: true),
      successMessage: 'Exercice "${ex.title}" désarchivé.',
    );
  }

  void _showPermanentDeleteExerciseConfirmation(BuildContext context, Exercise ex) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppTheme.accentRose,
      title: 'Supprimer définitivement "${ex.title}" ?',
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
        ),
        child: Text(
          'IRRÉVERSIBLE : cet exercice et toutes ses versions seront physiquement supprimés de la base.',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
        ),
      ),
      confirmLabel: 'Supprimer définitivement',
      confirmColor: AppTheme.accentRose,
      onConfirm: () => service.permanentlyDeleteExercise(ex.id, _currentAdminId()),
      successMessage: 'Exercice "${ex.title}" supprimé définitivement.',
      typedConfirmationTarget: ex.title,
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
    await ExercisePdfGenerator.printOrSave(exercise: ex, subjectName: subjectName, chapterTitle: chapterTitle);
  }

  Widget _buildLevelTab(String label) {
    final isSelected = _selectedLevelFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedLevelFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.primaryBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  /// Badge de classe/série ciblée. "Non classé" (rouge) signale un exercice indépendant qui n'a
  /// jamais reçu de classe — corrigible en un clic via le formulaire d'édition.
  Widget _buildClassBadge(Exercise ex, List<AcademicNode> classOptions) {
    if (ex.classNodeId == null) {
      return _buildBadge('Non classé', AppTheme.accentRose);
    }
    final matches = classOptions.where((c) => c.id == ex.classNodeId);
    final label = matches.isNotEmpty ? matches.first.name : 'Classe inconnue';
    return _buildBadge(label, AppTheme.accentBlue);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showVersionHistoryModal(BuildContext context, Exercise exercise) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.history_rounded,
          iconColor: AppTheme.accentCyan,
          text: 'Historique : ${exercise.title}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 520,
          height: 420,
          child: Consumer(
            builder: (context, ref, _) {
              final versionsAsync = ref.watch(exerciseVersionsProvider(exercise.id));
              return versionsAsync.when(
                data: (versions) {
                  if (versions.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucune version antérieure enregistrée — cet exercice n\'a jamais été modifié depuis sa création.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final v = versions[idx];
                      final statement = v.contentJson['instructions_json']?['statement'] as String? ?? '';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Version ${v.versionNumber}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(width: 8),
                                Text(v.publishedAt.toLocal().toString().split('.').first,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        backgroundColor: AppTheme.primarySurface,
                                        title: AppDialogTitle(
                                          icon: Icons.restore_rounded,
                                          text: 'Restaurer cette version ?',
                                          onClose: () => Navigator.pop(c, false),
                                        ),
                                        content: Text(
                                          'L\'énoncé et le corrigé actuels seront remplacés par ceux de la version ${v.versionNumber}.',
                                          style: GoogleFonts.inter(color: Colors.white70),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                                          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restaurer')),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    final service = ref.read(supabaseServiceProvider);
                                    await service.updateExercise(
                                      id: exercise.id,
                                      instructionsJson:
                                          Map<String, dynamic>.from(v.contentJson['instructions_json'] as Map? ?? {}),
                                      solutionJson:
                                          Map<String, dynamic>.from(v.contentJson['solution_json'] as Map? ?? {}),
                                      editedBy: _currentAdminId(),
                                    );
                                    ref.invalidate(exercisesProvider);
                                    ref.invalidate(exerciseVersionsProvider(exercise.id));
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: Text('Restaurer', style: GoogleFonts.inter(color: AppTheme.accentEmerald)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              statement.isEmpty ? '(énoncé vide)' : statement,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Fermer', style: GoogleFonts.inter(color: AppTheme.textMuted))),
        ],
      ),
    );
  }

  void _showCreateExerciseModal(BuildContext context, {Exercise? existing}) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final instructionsController = TextEditingController(
      text: existing?.instructionsJson['statement'] as String? ?? '',
    );
    final solutionController = TextEditingController(
      text: existing?.solutionJson['correction'] as String? ?? '',
    );
    ExerciseType selectedType = existing?.type ?? ExerciseType.training;
    ExerciseFormat selectedFormat = existing?.format ?? ExerciseFormat.qcm;
    ExerciseDifficulty selectedDifficulty = existing?.difficulty ?? ExerciseDifficulty.facile;
    String selectedTier = existing?.minSubscriptionTier ?? 'gratuit';
    String? selectedChapterId = existing?.chapterId;
    String? selectedClassNodeId = existing?.classNodeId;
    String? selectedTermId = existing?.termId;
    List<MediaAsset> attachedStatementMedia =
        ((existing?.instructionsJson['media'] as List?) ?? [])
            .map((m) => MediaAsset(
                  id: '',
                  filename: m['filename'] as String? ?? '',
                  type: m['type'] as String? ?? 'document',
                  url: m['url'] as String? ?? '',
                  uploadedBy: '',
                ))
            .toList();
    List<MediaAsset> attachedSolutionMedia =
        ((existing?.solutionJson['media'] as List?) ?? [])
            .map((m) => MediaAsset(
                  id: '',
                  filename: m['filename'] as String? ?? '',
                  type: m['type'] as String? ?? 'document',
                  url: m['url'] as String? ?? '',
                  uploadedBy: '',
                ))
            .toList();
    final existingOptions = (existing?.instructionsJson['options'] as List?)
            ?.map((o) => o.toString())
            .toList() ??
        <String>[];
    final optionControllers = (existingOptions.isEmpty ? ['', ''] : existingOptions)
        .map((o) => TextEditingController(text: o))
        .toList();
    int? correctOptionIndex = existing?.solutionJson['correct_index'] as int?;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dialogWidth = MediaQuery.of(context).size.width * 0.85;
          return AlertDialog(
            backgroundColor: AppTheme.primarySurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: AppDialogTitle(
              icon: Icons.fitness_center_rounded,
              text: isEditing ? 'Modifier l\'Exercice' : 'Créer un Exercice Pédagogique',
              onClose: () => Navigator.pop(ctx),
            ),
            content: SizedBox(
              width: dialogWidth > 1080 ? 1080 : dialogWidth,
              height: MediaQuery.of(context).size.height * 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Aperçus — toujours visibles, sans avoir à faire défiler le formulaire.
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentRose,
                          side: const BorderSide(color: AppTheme.accentRose),
                        ),
                        onPressed: () => _previewDraftAsPdf(
                          existing: existing,
                          selectedChapterId: selectedChapterId,
                          title: titleController.text.trim(),
                          type: selectedType,
                          difficulty: selectedDifficulty,
                          format: selectedFormat,
                          tier: selectedTier,
                          statement: instructionsController.text.trim(),
                          correction: solutionController.text.trim(),
                          options: optionControllers.map((c) => c.text.trim()).toList(),
                          statementMedia: attachedStatementMedia,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('Aperçu PDF'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                        ),
                        onPressed: () => _showStudentPreviewModal(
                          context,
                          title: titleController.text.trim().isEmpty
                              ? '(Sans titre)'
                              : titleController.text.trim(),
                          type: selectedType,
                          format: selectedFormat,
                          difficulty: selectedDifficulty,
                          statement: instructionsController.text.trim(),
                          statementMedia: attachedStatementMedia,
                          options: optionControllers.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList(),
                          correctIndex: correctOptionIndex,
                          correction: solutionController.text.trim(),
                        ),
                        icon: const Icon(Icons.smartphone_rounded, size: 18),
                        label: const Text('Aperçu App Élève'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppTheme.primaryBorder),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Colonne gauche : classification
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: titleController,
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Titre / Intitulé de l\'exercice',
                                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _ChapterPicker(
                                  selectedChapterId: selectedChapterId,
                                  onChanged: ({chapterId, classNodeId, subjectId, termId}) => setModalState(() {
                                    selectedChapterId = chapterId;
                                    selectedClassNodeId = classNodeId;
                                    selectedTermId = termId;
                                  }),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      // ignore: deprecated_member_use
                                      child: DropdownButtonFormField<ExerciseType>(
                                        // ignore: deprecated_member_use
                                        value: selectedType,
                                        isExpanded: true,
                                        dropdownColor: AppTheme.primaryDark,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(labelText: 'Type'),
                                        items: const [
                                          DropdownMenuItem(value: ExerciseType.training, child: Text('Entraînement')),
                                          DropdownMenuItem(value: ExerciseType.evaluation, child: Text('Évaluation')),
                                        ],
                                        onChanged: (v) =>
                                            setModalState(() => selectedType = v ?? ExerciseType.training),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      // ignore: deprecated_member_use
                                      child: DropdownButtonFormField<ExerciseDifficulty>(
                                        // ignore: deprecated_member_use
                                        value: selectedDifficulty,
                                        isExpanded: true,
                                        dropdownColor: AppTheme.primaryDark,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(labelText: 'Difficulté'),
                                        items: const [
                                          DropdownMenuItem(value: ExerciseDifficulty.facile, child: Text('Facile')),
                                          DropdownMenuItem(
                                              value: ExerciseDifficulty.intermediaire, child: Text('Intermédiaire')),
                                          DropdownMenuItem(
                                              value: ExerciseDifficulty.approfondissement,
                                              child: Text('Approfondi')),
                                        ],
                                        onChanged: (v) => setModalState(
                                            () => selectedDifficulty = v ?? ExerciseDifficulty.facile),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      // ignore: deprecated_member_use
                                      child: DropdownButtonFormField<ExerciseFormat>(
                                        // ignore: deprecated_member_use
                                        value: selectedFormat,
                                        isExpanded: true,
                                        dropdownColor: AppTheme.primaryDark,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(labelText: 'Format'),
                                        items: const [
                                          DropdownMenuItem(value: ExerciseFormat.qcm, child: Text('QCM')),
                                          DropdownMenuItem(
                                              value: ExerciseFormat.reponseCourte, child: Text('Réponse courte')),
                                          DropdownMenuItem(value: ExerciseFormat.redaction, child: Text('Rédaction')),
                                          DropdownMenuItem(
                                              value: ExerciseFormat.manuscritScan, child: Text('Manuscrit scanné')),
                                          DropdownMenuItem(value: ExerciseFormat.flashcard, child: Text('Flashcard')),
                                        ],
                                        onChanged: (v) =>
                                            setModalState(() => selectedFormat = v ?? ExerciseFormat.qcm),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      // ignore: deprecated_member_use
                                      child: DropdownButtonFormField<String>(
                                        // ignore: deprecated_member_use
                                        value: selectedTier,
                                        isExpanded: true,
                                        dropdownColor: AppTheme.primaryDark,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(labelText: 'Accès requis'),
                                        items: const [
                                          DropdownMenuItem(value: 'gratuit', child: Text('Gratuit')),
                                          DropdownMenuItem(value: 'journalier', child: Text('Journalier')),
                                          DropdownMenuItem(value: 'mensuel', child: Text('Mensuel')),
                                        ],
                                        onChanged: (v) => setModalState(() => selectedTier = v ?? 'gratuit'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (selectedFormat == ExerciseFormat.manuscritScan) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentIndigo.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accentIndigo),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Format "Manuscrit scanné" : joignez la photo/scan de l\'énoncé et/ou du '
                                            'corrigé via les pièces jointes ci-contre, à droite.',
                                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        const VerticalDivider(width: 1, color: AppTheme.primaryBorder),
                        const SizedBox(width: 24),
                        // Colonne droite : contenu (énoncé, options, corrigé, pièces jointes)
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: instructionsController,
                                  maxLines: 5,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'Énoncé de l\'exercice'),
                                  onChanged: (_) => setModalState(() {}),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: MediaAttachmentPicker(
                                    initialAssets: attachedStatementMedia,
                                    onChanged: (assets) => attachedStatementMedia = assets,
                                  ),
                                ),
                                if (selectedFormat == ExerciseFormat.qcm) ...[
                                  const SizedBox(height: 20),
                                  Text('Options de réponse (QCM)',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text('Cochez la bonne réponse.',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 10),
                                  ...List.generate(optionControllers.length, (i) {
                                    final letter = String.fromCharCode(65 + i);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          // ignore: deprecated_member_use
                                          Radio<int>(
                                            value: i,
                                            // ignore: deprecated_member_use
                                            groupValue: correctOptionIndex,
                                            activeColor: AppTheme.accentEmerald,
                                            // ignore: deprecated_member_use
                                            onChanged: (v) => setModalState(() => correctOptionIndex = v),
                                          ),
                                          Text(letter,
                                              style: GoogleFonts.outfit(
                                                  color: Colors.white70, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: optionControllers[i],
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText: 'Option $letter',
                                              ),
                                            ),
                                          ),
                                          if (optionControllers.length > 2)
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.accentRose),
                                              onPressed: () => setModalState(() {
                                                optionControllers.removeAt(i);
                                                if (correctOptionIndex == i) {
                                                  correctOptionIndex = null;
                                                } else if (correctOptionIndex != null && correctOptionIndex! > i) {
                                                  correctOptionIndex = correctOptionIndex! - 1;
                                                }
                                              }),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (optionControllers.length < 6)
                                    TextButton.icon(
                                      onPressed: () =>
                                          setModalState(() => optionControllers.add(TextEditingController())),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Ajouter une option'),
                                    ),
                                ],
                                const SizedBox(height: 20),
                                TextField(
                                  controller: solutionController,
                                  maxLines: 5,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'Corrigé (optionnel à ce stade)'),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: MediaAttachmentPicker(
                                    initialAssets: attachedSolutionMedia,
                                    onChanged: (assets) => attachedSolutionMedia = assets,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: submitError!),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          setModalState(() => submitError = 'Le titre est obligatoire.');
                          return;
                        }
                        if (selectedChapterId == null && selectedClassNodeId == null) {
                          setModalState(() => submitError =
                              'La classe/série est obligatoire pour un exercice indépendant (sans chapitre).');
                          return;
                        }
                        setModalState(() {
                          submitError = null;
                          isLoading = true;
                        });
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          final statementMediaPayload = attachedStatementMedia
                              .map((a) => {'url': a.url, 'filename': a.filename, 'type': a.type})
                              .toList();
                          final solutionMediaPayload = attachedSolutionMedia
                              .map((a) => {'url': a.url, 'filename': a.filename, 'type': a.type})
                              .toList();
                          final options = optionControllers
                              .map((c) => c.text.trim())
                              .where((o) => o.isNotEmpty)
                              .toList();
                          final instructionsJson = {
                            'statement': instructionsController.text.trim(),
                            'media': statementMediaPayload,
                            if (selectedFormat == ExerciseFormat.qcm && options.isNotEmpty) 'options': options,
                          };
                          final solutionJson = {
                            'correction': solutionController.text.trim(),
                            'media': solutionMediaPayload,
                            if (selectedFormat == ExerciseFormat.qcm && correctOptionIndex != null)
                              'correct_index': correctOptionIndex,
                          };

                          if (isEditing) {
                            await service.updateExercise(
                              id: existing.id,
                              title: title,
                              type: selectedType,
                              difficulty: selectedDifficulty,
                              format: selectedFormat,
                              instructionsJson: instructionsJson,
                              solutionJson: solutionJson,
                              minSubscriptionTier: selectedTier,
                              updateChapterId: true,
                              chapterId: selectedChapterId,
                              updateClassNodeId: true,
                              classNodeId: selectedClassNodeId,
                              updateTermId: true,
                              termId: selectedTermId,
                              editedBy: _currentAdminId(),
                            );
                          } else {
                            final exercise = await service.createExercise(
                              chapterId: selectedChapterId,
                              classNodeId: selectedClassNodeId,
                              termId: selectedTermId,
                              type: selectedType,
                              difficulty: selectedDifficulty,
                              format: selectedFormat,
                              title: title,
                              instructionsJson: instructionsJson,
                              solutionJson: solutionJson,
                              minSubscriptionTier: selectedTier,
                            );

                            if (exercise != null) {
                              await service.submitOrAutoApprove(
                                contentId: exercise.id,
                                contentType: 'exercise',
                                authorId: _currentAdminId(),
                                isSuperAdmin: ref.read(authProvider).valueOrNull?.isSuperAdmin ?? false,
                              );
                            }
                          }

                          ref.invalidate(exercisesProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.accentEmerald,
                                content: Text(
                                  isEditing
                                      ? 'Exercice "$title" mis à jour !'
                                      : 'Exercice "$title" créé et soumis pour validation !',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            submitError = '$e';
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Enregistrer les modifications' : 'Enregistrer l\'exercice'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Génère un PDF d'aperçu à partir de l'état courant du formulaire (pas encore enregistré),
  /// pour que l'admin voie le rendu imprimé avant de sauvegarder — même générateur que
  /// l'export PDF final (ExercisePdfGenerator), garantissant que l'aperçu est fidèle au résultat.
  Future<void> _previewDraftAsPdf({
    required Exercise? existing,
    required String? selectedChapterId,
    required String title,
    required ExerciseType type,
    required ExerciseDifficulty difficulty,
    required ExerciseFormat format,
    required String tier,
    required String statement,
    required String correction,
    required List<String> options,
    required List<MediaAsset> statementMedia,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    String subjectName = 'Matière';
    String? chapterTitle;
    if (selectedChapterId != null) {
      final chapter = await service.getChapter(selectedChapterId);
      if (chapter != null) {
        chapterTitle = chapter.title;
        final subject = await service.getSubject(chapter.subjectId);
        if (subject != null) subjectName = subject.name;
      }
    }
    final draft = Exercise(
      id: existing?.id ?? 'apercu',
      type: type,
      difficulty: difficulty,
      format: format,
      title: title.isEmpty ? '(Sans titre)' : title,
      minSubscriptionTier: tier,
      instructionsJson: {
        'statement': statement,
        'media': statementMedia.map((a) => {'url': a.url, 'filename': a.filename, 'type': a.type}).toList(),
        if (format == ExerciseFormat.qcm && options.where((o) => o.isNotEmpty).isNotEmpty)
          'options': options.where((o) => o.isNotEmpty).toList(),
      },
      solutionJson: {'correction': correction},
    );
    await ExercisePdfGenerator.printOrSave(exercise: draft, subjectName: subjectName, chapterTitle: chapterTitle);
  }

  /// Maquette illustrative de l'affichage côté application élève (celle-ci n'existe pas encore
  /// dans ce dépôt — c'est une approximation fidèle au CDC, construite avec les mêmes données que
  /// le PDF, pour que l'admin visualise le rendu avant publication plutôt qu'à l'aveugle.
  void _showStudentPreviewModal(
    BuildContext context, {
    required String title,
    required ExerciseType type,
    required ExerciseFormat format,
    required ExerciseDifficulty difficulty,
    required String statement,
    required List<MediaAsset> statementMedia,
    required List<String> options,
    required int? correctIndex,
    required String correction,
  }) {
    bool showCorrection = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPreviewState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FA),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aperçu — Application Élève',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _studentBadge(exerciseTypeToDb(type), const Color(0xFF1E3A8A)),
                            _studentBadge(exerciseFormatToDb(format), const Color(0xFF7C3AED)),
                            _studentBadge(exerciseDifficultyToDb(difficulty), const Color(0xFF0891B2)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                              fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          statement.isEmpty ? 'Aucun énoncé rédigé pour le moment.' : statement,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF374151), height: 1.5),
                        ),
                        if (statementMedia.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: statementMedia
                                .map((m) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF4B5563)),
                                          const SizedBox(width: 4),
                                          Text(m.filename,
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4B5563))),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                        if (format == ExerciseFormat.qcm && options.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          ...List.generate(options.length, (i) {
                            final letter = String.fromCharCode(65 + i);
                            final isCorrect = showCorrection && correctIndex == i;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isCorrect ? const Color(0xFFD1FAE5) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                                    width: isCorrect ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                          isCorrect ? const Color(0xFF10B981) : const Color(0xFFEEF2FF),
                                      child: Text(letter,
                                          style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isCorrect ? Colors.white : const Color(0xFF1E3A8A))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(options[i],
                                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF111827))),
                                    ),
                                    if (isCorrect)
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E3A8A),
                              side: const BorderSide(color: Color(0xFF1E3A8A)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => setPreviewState(() => showCorrection = !showCorrection),
                            icon: Icon(showCorrection ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 18),
                            label: Text(showCorrection ? 'Masquer la correction' : 'Voir la correction'),
                          ),
                        ),
                        if (showCorrection) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              correction.isEmpty ? 'Aucun corrigé rédigé pour le moment.' : correction,
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF065F46), height: 1.5),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Aperçu illustratif — le rendu réel dans l\'application élève pourra différer légèrement.',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _studentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _showAiGenerationModal(BuildContext context) {
    String? selectedSubjectId;
    String? selectedChapterId;
    String? selectedClassNodeId;
    String? selectedTermId;
    ExerciseType selectedType = ExerciseType.training;
    ExerciseFormat selectedFormat = ExerciseFormat.qcm;
    ExerciseDifficulty selectedDifficulty = ExerciseDifficulty.facile;
    final countController = TextEditingController(text: '5');
    final notesController = TextEditingController();
    String? submitError;
    bool isGenerating = false;
    List<Map<String, dynamic>>? generated;
    Set<int> selectedIndices = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.psychology_rounded,
            iconColor: AppTheme.accentCyan,
            text: 'Génération d\'Exercices par IA',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 560,
            height: MediaQuery.of(context).size.height * 0.65,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (generated == null) ...[
                    _ChapterPicker(
                      selectedChapterId: selectedChapterId,
                      onChanged: ({chapterId, classNodeId, subjectId, termId}) => setModalState(() {
                        selectedChapterId = chapterId;
                        selectedClassNodeId = classNodeId;
                        selectedSubjectId = subjectId;
                        selectedTermId = termId;
                      }),
                    ),
                    const SizedBox(height: 16),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<ExerciseType>(
                      // ignore: deprecated_member_use
                      value: selectedType,
                      dropdownColor: AppTheme.primaryDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: ExerciseType.training, child: Text('Entraînement')),
                        DropdownMenuItem(value: ExerciseType.evaluation, child: Text('Évaluation')),
                      ],
                      onChanged: (v) => setModalState(() => selectedType = v ?? ExerciseType.training),
                    ),
                    const SizedBox(height: 16),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<ExerciseFormat>(
                      // ignore: deprecated_member_use
                      value: selectedFormat,
                      dropdownColor: AppTheme.primaryDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Format'),
                      items: const [
                        DropdownMenuItem(value: ExerciseFormat.qcm, child: Text('QCM')),
                        DropdownMenuItem(value: ExerciseFormat.reponseCourte, child: Text('Réponse courte')),
                        DropdownMenuItem(value: ExerciseFormat.redaction, child: Text('Rédaction')),
                      ],
                      onChanged: (v) => setModalState(() => selectedFormat = v ?? ExerciseFormat.qcm),
                    ),
                    const SizedBox(height: 16),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<ExerciseDifficulty>(
                      // ignore: deprecated_member_use
                      value: selectedDifficulty,
                      dropdownColor: AppTheme.primaryDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Difficulté'),
                      items: const [
                        DropdownMenuItem(value: ExerciseDifficulty.facile, child: Text('Facile')),
                        DropdownMenuItem(value: ExerciseDifficulty.intermediaire, child: Text('Intermédiaire')),
                        DropdownMenuItem(value: ExerciseDifficulty.approfondissement, child: Text('Approfondissement')),
                      ],
                      onChanged: (v) => setModalState(() => selectedDifficulty = v ?? ExerciseDifficulty.facile),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Nombre d\'exercices à générer (1-20)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Notes / directives (optionnel)',
                        hintText: 'Ex: se concentrer sur les identités remarquables',
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${generated!.length} exercice(s) généré(s) — décochez ceux à ignorer, puis créez les exercices sélectionnés.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(generated!.length, (i) {
                      final ex = generated![i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: CheckboxListTile(
                          value: selectedIndices.contains(i),
                          activeColor: AppTheme.accentEmerald,
                          onChanged: (v) => setModalState(() {
                            if (v == true) {
                              selectedIndices.add(i);
                            } else {
                              selectedIndices.remove(i);
                            }
                          }),
                          title: Text(ex['title'] as String? ?? 'Sans titre',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(
                            ex['statement'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ),
                      );
                    }),
                  ],
                  if (submitError != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: submitError!),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isGenerating ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            if (generated == null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                onPressed: isGenerating
                    ? null
                    : () async {
                        if (selectedChapterId == null && selectedClassNodeId == null) {
                          setModalState(() => submitError =
                              'La classe/série est obligatoire pour générer un exercice indépendant (sans chapitre).');
                          return;
                        }
                        final count = int.tryParse(countController.text.trim()) ?? 5;
                        setModalState(() {
                          isGenerating = true;
                          submitError = null;
                        });
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          final result = await service.generateAiExercises(
                            subjectId: selectedSubjectId,
                            chapterId: selectedChapterId,
                            type: selectedType,
                            difficulty: selectedDifficulty,
                            format: selectedFormat,
                            count: count,
                            rawNotes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          );
                          setModalState(() {
                            isGenerating = false;
                            generated = result;
                            selectedIndices = Set.from(List.generate(result.length, (i) => i));
                          });
                        } catch (e) {
                          setModalState(() {
                            isGenerating = false;
                            submitError = '$e';
                          });
                        }
                      },
                icon: isGenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(isGenerating ? 'Génération en cours...' : 'Générer'),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                onPressed: isGenerating || selectedIndices.isEmpty
                    ? null
                    : () async {
                        setModalState(() => isGenerating = true);
                        final service = ref.read(supabaseServiceProvider);
                        var created = 0;
                        // Snapshot de la sélection : en cas d'échec au milieu du lot (réseau...),
                        // on retire du Set d'origine chaque index déjà créé AVANT de relancer
                        // l'exception, pour qu'un nouveau clic sur "Créer" ne retente que les
                        // exercices pas encore créés au lieu de dupliquer ceux déjà en base.
                        for (final i in selectedIndices.toList()) {
                          try {
                            final item = generated![i];
                            final options = (item['options'] as List?)?.cast<String>();
                            final correctIndex = item['correct_index'] as int?;
                            final exercise = await service.createExercise(
                              chapterId: selectedChapterId,
                              classNodeId: selectedClassNodeId,
                              termId: selectedTermId,
                              type: selectedType,
                              difficulty: selectedDifficulty,
                              format: selectedFormat,
                              title: item['title'] as String? ?? 'Exercice généré',
                              instructionsJson: {
                                'statement': item['statement'] as String? ?? '',
                                'options': ?options,
                                'media': [],
                              },
                              solutionJson: {
                                'correction': item['correction'] as String? ?? '',
                                'correct_index': ?correctIndex,
                              },
                            );
                            if (exercise != null) {
                              await service.submitOrAutoApprove(
                                contentId: exercise.id,
                                contentType: 'exercise',
                                authorId: _currentAdminId(),
                                isSuperAdmin: ref.read(authProvider).valueOrNull?.isSuperAdmin ?? false,
                              );
                              created++;
                              selectedIndices.remove(i);
                            }
                          } catch (e) {
                            setModalState(() {
                              isGenerating = false;
                              submitError = '$created exercice(s) créé(s) avant l\'erreur : $e. '
                                  'Cliquez à nouveau pour retenter uniquement les restants.';
                            });
                            ref.invalidate(exercisesProvider);
                            return;
                          }
                        }
                        ref.invalidate(exercisesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text('$created exercice(s) créé(s) et soumis pour validation !'),
                            ),
                          );
                        }
                      },
                icon: isGenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text('Créer ${selectedIndices.length} exercice(s)'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'erreur réutilisable (messages d'exception potentiellement longs, affichés à part
/// plutôt que dans un TextField.errorText).
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentRose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.accentRose, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur Classe/Série → Matière → Chapitre (optionnel) → Trimestre pour rattacher un
/// exercice — même cheminement que le sélecteur de chapitre dans lessons_manager_screen.dart.
/// Choisir "Aucun" comme chapitre laisse l'exercice indépendant (Niveau 3 du CDC) ; dans ce cas
/// la Classe/Série reste le seul champ que l'appelant doit rendre obligatoire, puisqu'aucun
/// chapitre parent n'existe pour la déduire (le trigger SQL trg_sync_exercise_class_scope ne
/// peut dériver class_node_id/term_id que si chapter_id ou lesson_id est renseigné).
class _ChapterPicker extends ConsumerStatefulWidget {
  final String? selectedChapterId;
  final void Function({
    required String? chapterId,
    required String? classNodeId,
    required String? subjectId,
    required String? termId,
  }) onChanged;

  const _ChapterPicker({
    required this.selectedChapterId,
    required this.onChanged,
  });

  @override
  ConsumerState<_ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends ConsumerState<_ChapterPicker> {
  String? _selectedClassNodeId;
  String? _selectedSubjectId;
  String? _selectedChapterId;
  String? _selectedTermId;
  bool _resolvingInitial = false;

  @override
  void initState() {
    super.initState();
    _selectedChapterId = widget.selectedChapterId;
    if (widget.selectedChapterId != null) {
      _resolveInitial(widget.selectedChapterId!);
    }
  }

  Future<void> _resolveInitial(String chapterId) async {
    setState(() => _resolvingInitial = true);
    final service = ref.read(supabaseServiceProvider);
    final chapter = await service.getChapter(chapterId);
    if (!mounted) return;
    setState(() {
      _resolvingInitial = false;
      if (chapter != null) {
        _selectedClassNodeId = chapter.classNodeId;
        _selectedSubjectId = chapter.subjectId;
        _selectedTermId = chapter.termId;
      }
    });
  }

  void _notify() {
    widget.onChanged(
      chapterId: _selectedChapterId,
      classNodeId: _selectedClassNodeId,
      subjectId: _selectedSubjectId,
      termId: _selectedTermId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingInitial) {
      return const LinearProgressIndicator();
    }

    final classNodesAsync = ref.watch(nodesByTypeProvider('class'));
    final seriesNodesAsync = ref.watch(nodesByTypeProvider('series'));
    final classOptions = <AcademicNode>[
      ...classNodesAsync.valueOrNull ?? [],
      ...seriesNodesAsync.valueOrNull ?? [],
    ]..sort((a, b) => a.name.compareTo(b.name));

    final subjectsAsync = _selectedClassNodeId == null
        ? null
        : ref.watch(subjectsForClassProvider(_selectedClassNodeId!));
    final subjects = subjectsAsync?.valueOrNull ?? [];

    final chaptersAsync = (_selectedClassNodeId == null || _selectedSubjectId == null)
        ? null
        : ref.watch(chaptersWithLessonsProvider((
            subjectId: _selectedSubjectId!,
            classNodeId: _selectedClassNodeId,
            includeInactive: false,
          )));
    final chapters = chaptersAsync?.valueOrNull ?? [];

    final countryNodesAsync = ref.watch(nodesByTypeProvider('country'));
    final countryId = countryNodesAsync.valueOrNull?.isNotEmpty == true
        ? countryNodesAsync.valueOrNull!.first.id
        : null;
    final termsAsync = countryId == null ? null : ref.watch(termsProvider(countryId));
    final terms = termsAsync?.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ignore: deprecated_member_use
        DropdownButtonFormField<String?>(
          // ignore: deprecated_member_use
          value: _selectedClassNodeId,
          isExpanded: true,
          dropdownColor: AppTheme.primaryDark,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Classe / Série',
            helperText: 'Obligatoire pour un exercice indépendant ; simple filtre de navigation sinon',
            prefixIcon: Icon(Icons.school_rounded, size: 20),
          ),
          items: [
            ...classOptions.map(
                (c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
            // La classe du chapitre d'origine peut avoir été archivée depuis l'Arbre Académique :
            // sans cette entrée, `value` ne correspondrait à aucun `item` et le dropdown planterait
            // à l'ouverture du formulaire d'édition.
            if (_selectedClassNodeId != null && !classOptions.any((c) => c.id == _selectedClassNodeId))
              DropdownMenuItem<String?>(
                value: _selectedClassNodeId,
                child: Text('Classe archivée (id: ${_selectedClassNodeId!.substring(0, 8)}…)',
                    style: const TextStyle(color: AppTheme.accentAmber), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            _selectedClassNodeId = v;
            _selectedSubjectId = null;
            _selectedChapterId = null;
            _notify();
          }),
        ),
        if (_selectedClassNodeId != null) ...[
          const SizedBox(height: 12),
          subjects.isEmpty
              ? Text('Aucune matière liée à cette classe.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted))
              // ignore: deprecated_member_use
              : DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: _selectedSubjectId,
                  isExpanded: true,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Matière'),
                  items: [
                    ...subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                    if (_selectedSubjectId != null && !subjects.any((s) => s.id == _selectedSubjectId))
                      DropdownMenuItem<String?>(
                        value: _selectedSubjectId,
                        child: Text('Matière archivée (id: ${_selectedSubjectId!.substring(0, 8)}…)',
                            style: const TextStyle(color: AppTheme.accentAmber), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedSubjectId = v;
                    _selectedChapterId = null;
                    _notify();
                  }),
                ),
        ],
        if (_selectedSubjectId != null) ...[
          const SizedBox(height: 12),
          // ignore: deprecated_member_use
          DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: _selectedChapterId,
            isExpanded: true,
            dropdownColor: AppTheme.primaryDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Chapitre (optionnel — laisser vide = exercice indépendant)',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Aucun (exercice indépendant)')),
              ...chapters.map(
                (c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.title, overflow: TextOverflow.ellipsis)),
              ),
              // Le chapitre d'origine peut avoir été archivé depuis cette même page : sans cette
              // entrée, `value` ne correspondrait à aucun `item` et le dropdown planterait.
              if (_selectedChapterId != null && !chapters.any((c) => c.id == _selectedChapterId))
                DropdownMenuItem<String?>(
                  value: _selectedChapterId,
                  child: Text('Chapitre archivé (id: ${_selectedChapterId!.substring(0, 8)}…)',
                      style: const TextStyle(color: AppTheme.accentAmber), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _selectedChapterId = v;
              if (v != null) {
                final match = chapters.where((c) => c.id == v);
                _selectedTermId = match.isNotEmpty ? match.first.termId : null;
              }
              _notify();
            }),
          ),
        ],
        if (_selectedChapterId != null) ...[
          const SizedBox(height: 8),
          Text(
            'Classe et trimestre hérités automatiquement du chapitre sélectionné.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ] else if (_selectedClassNodeId != null) ...[
          const SizedBox(height: 12),
          // ignore: deprecated_member_use
          DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: _selectedTermId,
            isExpanded: true,
            dropdownColor: AppTheme.primaryDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Trimestre (optionnel)',
              prefixIcon: Icon(Icons.calendar_month_rounded, size: 20),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Aucun trimestre spécifique')),
              // Les trimestres archivés restent sélectionnables uniquement s'ils sont déjà choisis
              // (édition d'un exercice existant) — sinon exclus des nouvelles sélections.
              ...terms.where((t) => t.isActive || t.id == _selectedTermId).map(
                (t) => DropdownMenuItem<String?>(
                  value: t.id,
                  child: Text(
                    t.isActive ? '${t.name} (${t.schoolYear})' : '${t.name} (${t.schoolYear}) — archivé',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() {
              _selectedTermId = v;
              _notify();
            }),
          ),
        ],
      ],
    );
  }
}
