import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/math_text.dart';
import '../utils/exercise_pdf_generator.dart';
import 'exercise_ai_generation_screen.dart';
import 'exercise_student_preview_screen.dart';
import 'exercise_studio_screen.dart';

/// Fiche détaillée d'un exercice pédagogique EDLEARN.
///
/// Vraie page dédiée plein écran remplaçant les inspecteurs latéraux étriqués
/// et les boîtes de dialogue condensées. Elle offre un espace d'examen et
/// d'inspection aéré, spacieux et fidèle à la pédagogie scientifique.
class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final String? exerciseId;
  final Exercise? initialExercise;

  const ExerciseDetailScreen({
    super.key,
    this.exerciseId,
    this.initialExercise,
  }) : assert(
          exerciseId != null || initialExercise != null,
          'exerciseId ou initialExercise requis',
        );

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  Exercise? _exercise;
  bool _isLoading = false;
  String? _errorMessage;

  // États contextuels résolus
  String? _className;
  String? _subjectName;
  String? _chapterTitle;
  String? _lessonTitle;

  // Simulation interactive
  int? _simulatedOptionIndex;
  bool _showCorrection = false;
  int _revealedHintsCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialExercise != null) {
      _exercise = widget.initialExercise;
      _resolveContext(_exercise!);
    } else if (widget.exerciseId != null) {
      _loadExercise(widget.exerciseId!);
    }
  }

  Future<void> _loadExercise(String id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(supabaseServiceProvider);
      final ex = await service.getExercise(id);
      if (ex != null && mounted) {
        setState(() => _exercise = ex);
        await _resolveContext(ex);
      } else if (mounted) {
        setState(() => _errorMessage = 'Exercice introuvable.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveContext(Exercise ex) async {
    final service = ref.read(supabaseServiceProvider);

    if (ex.lessonId != null) {
      final lesson = await service.getLesson(ex.lessonId!);
      if (lesson != null && mounted) {
        setState(() => _lessonTitle = lesson.title);
      }
    }

    if (ex.chapterId != null) {
      final chapter = await service.getChapter(ex.chapterId!);
      if (chapter != null && mounted) {
        setState(() => _chapterTitle = chapter.title);
        final subject = await service.getSubject(chapter.subjectId);
        if (subject != null && mounted) {
          setState(() => _subjectName = subject.name);
        }
      }
    }

    if (ex.classNodeId != null) {
      final node = await service.getNode(ex.classNodeId!);
      if (node != null && mounted) {
        setState(() => _className = node.name);
      }
    }
  }

  String _currentAdminId() {
    return ref.read(authProvider).valueOrNull?.id ??
        '00000000-0000-0000-0000-000000000001';
  }

  Future<void> _togglePublish() async {
    if (_exercise == null) return;
    final newStatus = !_exercise!.isPublished;
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.publishExercise(_exercise!.id, newStatus);
      if (mounted) {
        setState(() {
          _exercise = Exercise(
            id: _exercise!.id,
            lessonId: _exercise!.lessonId,
            chapterId: _exercise!.chapterId,
            classNodeId: _exercise!.classNodeId,
            termId: _exercise!.termId,
            type: _exercise!.type,
            difficulty: _exercise!.difficulty,
            format: _exercise!.format,
            title: _exercise!.title,
            instructionsJson: _exercise!.instructionsJson,
            solutionJson: _exercise!.solutionJson,
            minSubscriptionTier: _exercise!.minSubscriptionTier,
            isPublished: newStatus,
            isActive: _exercise!.isActive,
            skills: _exercise!.skills,
            prerequisites: _exercise!.prerequisites,
            provenance: _exercise!.provenance,
            displayOrder: _exercise!.displayOrder,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'Exercice publié avec succès' : 'Exercice repassé en brouillon',
            ),
            backgroundColor: newStatus ? AppTheme.accentEmerald : AppTheme.accentAmber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  void _openStudio() {
    if (_exercise == null) return;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseStudioScreen(
          exerciseId: _exercise!.id,
          existingExercise: _exercise,
        ),
      ),
    ).then((updated) {
      ref.invalidate(exercisesProvider);
      if (_exercise != null) _loadExercise(_exercise!.id);
    });
  }

  void _openStudentPreview() {
    if (_exercise == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseStudentPreviewScreen(exercise: _exercise!),
      ),
    );
  }

  void _openAiVariantGenerator() {
    if (_exercise == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseAiGenerationScreen(
          initialClassNodeId: _exercise!.classNodeId,
          initialChapterId: _exercise!.chapterId,
          initialType: _exercise!.type,
          initialFormat: _exercise!.format,
          initialDifficulty: _exercise!.difficulty,
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_exercise == null) return;
    await ExercisePdfGenerator.printOrSave(
      exercise: _exercise!,
      subjectName: _subjectName ?? 'Discipline',
      chapterTitle: _chapterTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    if (_errorMessage != null || _exercise == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        appBar: AppBar(
          backgroundColor: AppTheme.primarySurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Fiche d\'Exercice',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.accentRose),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Exercice non trouvé.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
                label: const Text('Retour à la Banque', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    final ex = _exercise!;
    final statement = ex.instructionsJson['statement'] as String? ?? ex.title;
    final options = (ex.instructionsJson['options'] as List?)
            ?.map((o) => o.toString())
            .toList() ??
        [];
    final media = (ex.instructionsJson['media'] as List?) ?? [];
    final solutionText = ex.solutionJson['correction'] as String? ??
        ex.solutionJson['explanation'] as String? ??
        '';
    final correctOptionIndex = ex.solutionJson['correct_index'] as int?;
    final hints = ex.hints;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primarySurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Retour à la Banque d\'Exercices',
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildBreadcrumbs(),
        actions: [
          // Statut Publié / Brouillon interactif
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _togglePublish,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (ex.isPublished ? AppTheme.accentEmerald : AppTheme.accentAmber)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ex.isPublished ? AppTheme.accentEmerald : AppTheme.accentAmber,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ex.isPublished ? Icons.check_circle_rounded : Icons.pending_outlined,
                      size: 14,
                      color: ex.isPublished ? AppTheme.accentEmerald : AppTheme.accentAmber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ex.isPublished ? 'PUBLIÉ' : 'BROUILLON',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ex.isPublished ? AppTheme.accentEmerald : AppTheme.accentAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentCyan,
              side: const BorderSide(color: AppTheme.accentCyan),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _openStudentPreview,
            icon: const Icon(Icons.preview_rounded, size: 16),
            label: const Text('Aperçu Élève', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _openStudio,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Modifier dans le Studio', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accentRose),
            tooltip: 'Exporter en PDF',
            onPressed: _exportPdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: AppTheme.primarySurface,
            onSelected: (action) {
              if (action == 'ai') {
                _openAiVariantGenerator();
              } else if (action == 'duplicate') {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                ref.read(supabaseServiceProvider).duplicateExercise(ex.id, _currentAdminId()).then((_) {
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Exercice dupliqué avec succès')),
                    );
                    nav.pop();
                  }
                });
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'ai',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accentCyan),
                    SizedBox(width: 10),
                    Text('Générer variante IA', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 16, color: AppTheme.accentIndigo),
                    SizedBox(width: 10),
                    Text('Dupliquer l\'exercice', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 1050;

          final mainContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Énoncé & Médias
              _buildStatementCard(ex, statement, media),
              const SizedBox(height: 20),

              // 2. Choix & Simulation interactive (si QCM)
              if (options.isNotEmpty) ...[
                _buildInteractiveOptionsCard(options, correctOptionIndex),
                const SizedBox(height: 20),
              ],

              // 3. Corrigé Pédagogique & Indices
              _buildSolutionCard(solutionText, hints),
            ],
          );

          final sideMetadata = _buildMetadataPanel(ex);

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 13,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: mainContent,
                  ),
                ),
                Container(
                  width: 1,
                  height: double.infinity,
                  color: AppTheme.primaryBorder,
                ),
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: sideMetadata,
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mainContent,
                const SizedBox(height: 24),
                const Divider(color: AppTheme.primaryBorder),
                const SizedBox(height: 16),
                sideMetadata,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final parts = <String>['Banque d\'Exercices'];
    if (_className != null) parts.add(_className!);
    if (_subjectName != null) parts.add(_subjectName!);
    if (_chapterTitle != null) parts.add(_chapterTitle!);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
              ),
            Text(
              parts[i],
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: i == parts.length - 1 ? FontWeight.bold : FontWeight.normal,
                color: i == parts.length - 1 ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatementCard(Exercise ex, String statement, List media) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded, color: AppTheme.accentCyan, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.title,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildBadge(exerciseTypeToDb(ex.type), AppTheme.accentEmerald),
                        _buildBadge(exerciseFormatToDb(ex.format), AppTheme.accentIndigo),
                        _buildBadge(exerciseDifficultyToDb(ex.difficulty), AppTheme.accentCyan),
                        _buildBadge(ex.minSubscriptionTier.toUpperCase(), AppTheme.accentAmber),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.primaryBorder),
          const SizedBox(height: 16),
          Text(
            'ÉNONCÉ DE L\'EXERCICE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: MathText(
              statement,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.7,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          if (media.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'FIGURES ET DOCUMENTS JOINTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: media.map((m) {
                final url = m is Map ? m['url']?.toString() : m.toString();
                return Container(
                  constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    url ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.primaryDark,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveOptionsCard(List<String> options, int? correctIndex) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rule_rounded, color: AppTheme.accentEmerald, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choix QCM & Simulation de Réponse',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_simulatedOptionIndex != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _simulatedOptionIndex = null),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textMuted),
                  label: Text(
                    'Réinitialiser',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildOptionItem(
              letter: String.fromCharCode(65 + i),
              text: options[i],
              index: i,
              isCorrect: correctIndex == i,
              isSelected: _simulatedOptionIndex == i,
              onTap: () => setState(() => _simulatedOptionIndex = i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required String letter,
    required String text,
    required int index,
    required bool isCorrect,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    Color borderColor = AppTheme.primaryBorder;
    Color bgColor = AppTheme.primaryDark;

    if (isSelected) {
      if (isCorrect) {
        borderColor = AppTheme.accentEmerald;
        bgColor = AppTheme.accentEmerald.withValues(alpha: 0.12);
      } else {
        borderColor = AppTheme.accentRose;
        bgColor = AppTheme.accentRose.withValues(alpha: 0.12);
      }
    } else if (isCorrect) {
      borderColor = AppTheme.accentEmerald.withValues(alpha: 0.5);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected || isCorrect ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppTheme.accentEmerald.withValues(alpha: 0.2)
                    : AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? AppTheme.accentEmerald : AppTheme.primaryBorder,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? AppTheme.accentEmerald : Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: MathText(
                text,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              ),
            ),
            if (isCorrect)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'BONNE RÉPONSE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentEmerald,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionCard(String solutionText, List<String> hints) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppTheme.accentIndigo, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Corrigé Didactique & Démarche Pédagogique',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _showCorrection,
                activeThumbColor: AppTheme.accentEmerald,
                onChanged: (v) => setState(() => _showCorrection = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_showCorrection)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_outlined, color: AppTheme.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le corrigé détaillé est masqué. Activez l\'interrupteur ci-dessus pour inspecter la solution rédigée.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.3)),
              ),
              child: MathText(
                solutionText.isEmpty ? 'Aucune correction enregistrée.' : solutionText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.7,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'INDICES DIDACTIQUES PROGRESSIFS (${hints.length})',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (_revealedHintsCount < hints.length)
                  TextButton.icon(
                    onPressed: () => setState(() => _revealedHintsCount++),
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.accentAmber),
                    label: Text(
                      'Dévoiler l\'indice ${_revealedHintsCount + 1}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentAmber),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < hints.length; i++) ...[
              if (i < _revealedHintsCount || _showCorrection)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_rounded, size: 16, color: AppTheme.accentAmber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Indice ${i + 1} : ${hints[i]}',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataPanel(Exercise ex) {
    String levelLabel = 'Niveau 3 : Indépendant (Examen)';
    if (ex.lessonId != null) {
      levelLabel = 'Niveau 1 : Rattaché à une leçon précise';
    } else if (ex.chapterId != null) {
      levelLabel = 'Niveau 2 : Rattaché à un chapitre';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RATTACHEMENT ACADÉMIQUE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        _buildMetaItem(
          icon: Icons.layers_rounded,
          label: 'Niveau d\'indépendance',
          value: levelLabel,
          color: AppTheme.accentCyan,
        ),
        if (_className != null) ...[
          const SizedBox(height: 10),
          _buildMetaItem(
            icon: Icons.school_rounded,
            label: 'Classe / Série',
            value: _className!,
          ),
        ],
        if (_subjectName != null) ...[
          const SizedBox(height: 10),
          _buildMetaItem(
            icon: Icons.menu_book_rounded,
            label: 'Discipline / Matière',
            value: _subjectName!,
          ),
        ],
        if (_chapterTitle != null) ...[
          const SizedBox(height: 10),
          _buildMetaItem(
            icon: Icons.folder_copy_rounded,
            label: 'Chapitre',
            value: _chapterTitle!,
          ),
        ],
        if (_lessonTitle != null) ...[
          const SizedBox(height: 10),
          _buildMetaItem(
            icon: Icons.auto_stories_rounded,
            label: 'Leçon',
            value: _lessonTitle!,
          ),
        ],
        const SizedBox(height: 24),
        const Divider(color: AppTheme.primaryBorder),
        const SizedBox(height: 16),
        Text(
          'COMPÉTENCES & PRÉREQUIS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (ex.skills.isEmpty && ex.prerequisites.isEmpty)
          Text(
            'Aucune compétence ou prérequis balisé.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          )
        else ...[
          if (ex.skills.isNotEmpty) ...[
            Text('Compétences visées :', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ex.skills
                  .map((s) => _buildBadge(s, AppTheme.accentEmerald))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (ex.prerequisites.isNotEmpty) ...[
            Text('Prérequis :', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ex.prerequisites
                  .map((p) => _buildBadge(p, AppTheme.accentIndigo))
                  .toList(),
            ),
          ],
        ],
        const SizedBox(height: 24),
        const Divider(color: AppTheme.primaryBorder),
        const SizedBox(height: 16),
        Text(
          'TRAÇABILITÉ & PROVENANCE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        _buildMetaItem(
          icon: Icons.history_edu_rounded,
          label: 'Provenance',
          value: ex.provenance,
        ),
        const SizedBox(height: 10),
        _buildMetaItem(
          icon: Icons.sort_rounded,
          label: 'Ordre d\'affichage',
          value: '#${ex.displayOrder}',
        ),
        const SizedBox(height: 10),
        _buildMetaItem(
          icon: Icons.lock_outline_rounded,
          label: 'Formule requise',
          value: ex.minSubscriptionTier,
          color: AppTheme.accentAmber,
        ),
      ],
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
