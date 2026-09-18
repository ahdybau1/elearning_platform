import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/math_text.dart';

/// Écran dédié à la génération d'exercices assistée par IA.
///
/// Interface spacieuse et structurée remplaçant l'ancien dialogue modal :
/// permet de configurer le contexte curriculaire, de lancer la génération,
/// d'examiner les propositions avec rendu LaTeX et de les importer en base.
class ExerciseAiGenerationScreen extends ConsumerStatefulWidget {
  final String? initialClassNodeId;
  final String? initialChapterId;
  final ExerciseType? initialType;
  final ExerciseFormat? initialFormat;
  final ExerciseDifficulty? initialDifficulty;

  const ExerciseAiGenerationScreen({
    super.key,
    this.initialClassNodeId,
    this.initialChapterId,
    this.initialType,
    this.initialFormat,
    this.initialDifficulty,
  });

  @override
  ConsumerState<ExerciseAiGenerationScreen> createState() =>
      _ExerciseAiGenerationScreenState();
}

class _ExerciseAiGenerationScreenState
    extends ConsumerState<ExerciseAiGenerationScreen> {
  String? _selectedClassNodeId;
  String? _selectedSubjectId;
  String? _selectedChapterId;
  String? _selectedTermId;

  late ExerciseType _selectedType;
  late ExerciseFormat _selectedFormat;
  late ExerciseDifficulty _selectedDifficulty;

  final TextEditingController _countController = TextEditingController(text: '3');
  final TextEditingController _notesController = TextEditingController();

  bool _isGenerating = false;
  bool _isImporting = false;
  String? _errorMessage;

  List<Map<String, dynamic>>? _generatedExercises;
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _selectedClassNodeId = widget.initialClassNodeId;
    _selectedChapterId = widget.initialChapterId;
    _selectedType = widget.initialType ?? ExerciseType.training;
    _selectedFormat = widget.initialFormat ?? ExerciseFormat.qcm;
    _selectedDifficulty = widget.initialDifficulty ?? ExerciseDifficulty.facile;
  }

  @override
  void dispose() {
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _runAiGeneration() async {
    final count = int.tryParse(_countController.text.trim()) ?? 3;
    if (count < 1 || count > 15) {
      setState(() => _errorMessage = 'Le nombre d\'exercices doit être compris entre 1 et 15.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedExercises = null;
      _selectedIndices.clear();
    });

    try {
      final service = ref.read(supabaseServiceProvider);
      final result = await service.generateAiExercises(
        subjectId: _selectedSubjectId,
        chapterId: _selectedChapterId,
        type: _selectedType,
        difficulty: _selectedDifficulty,
        format: _selectedFormat,
        count: count,
        rawNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedExercises = result;
          _selectedIndices = Set.from(List.generate(result.length, (i) => i));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  Future<void> _importSelectedExercises() async {
    if (_generatedExercises == null || _selectedIndices.isEmpty) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    final service = ref.read(supabaseServiceProvider);
    var importedCount = 0;
    final toImport = _selectedIndices.toList();

    for (final i in toImport) {
      try {
        final item = _generatedExercises![i];
        final options = (item['options'] as List?)?.cast<String>();
        final correctIndex = item['correct_index'] as int?;
        final hints = (item['hints'] as List?)
                ?.map((h) => h.toString())
                .toList() ??
            const [];
        final skills = (item['skills'] as List?)
                ?.map((s) => s.toString())
                .toList() ??
            const [];
        final prerequisites = (item['prerequisites'] as List?)
                ?.map((p) => p.toString())
                .toList() ??
            const [];

        await service.createExercise(
          classNodeId: _selectedClassNodeId,
          chapterId: _selectedChapterId,
          termId: _selectedTermId,
          title: item['title'] as String? ?? 'Exercice IA #${i + 1}',
          type: _selectedType,
          format: _selectedFormat,
          difficulty: _selectedDifficulty,
          instructionsJson: {
            'statement': item['statement'] as String? ?? '',
            'options': ?options,
            'hints': hints,
          },
          solutionJson: {
            if (item['correction'] != null) 'correction': item['correction'],
            if (item['explanation'] != null) 'explanation': item['explanation'],
            'correct_index': ?correctIndex,
          },
          skills: skills,
          prerequisites: prerequisites,
          provenance: 'ai_generated',
        );

        importedCount++;
        _selectedIndices.remove(i);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isImporting = false;
            _errorMessage = 'Erreur lors de l\'import: $e';
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _isImporting = false);
      ref.invalidate(exercisesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$importedCount exercice(s) importé(s) avec succès dans la Banque !'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classNodesAsync = ref.watch(nodesByTypeProvider('class'));
    final seriesNodesAsync = ref.watch(nodesByTypeProvider('series'));
    final classOptions = mergeClassOptions(
      classNodesAsync.valueOrNull ?? [],
      seriesNodesAsync.valueOrNull ?? [],
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primarySurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Générateur d\'Exercices Assisté par IA',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Conception automatisée contextualisée au programme officiel',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 950;

          final configForm = _buildConfigurationForm(classOptions);
          final previewArea = _buildPreviewArea();

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: configForm,
                  ),
                ),
                Container(
                  width: 1,
                  height: double.infinity,
                  color: AppTheme.primaryBorder,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: previewArea,
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
                configForm,
                const SizedBox(height: 24),
                const Divider(color: AppTheme.primaryBorder),
                const SizedBox(height: 20),
                previewArea,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigurationForm(List<AcademicNode> classOptions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: AppTheme.accentCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Paramètres de Génération',
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
          const SizedBox(height: 20),

          // Sélecteur de Classe
          Text('Classe / Niveau', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: _selectedClassNodeId,
            isExpanded: true,
            dropdownColor: AppTheme.primaryDark,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.primaryDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Toutes classes / Indépendant'),
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
                _selectedClassNodeId = v;
                _selectedSubjectId = null;
                _selectedChapterId = null;
              });
            },
          ),
          const SizedBox(height: 14),

          // Typologie
          Text('Typologie Pédagogique', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<ExerciseType>(
            initialValue: _selectedType,
            dropdownColor: AppTheme.primaryDark,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.primaryDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: ExerciseType.training, child: Text('Entraînement')),
              DropdownMenuItem(value: ExerciseType.evaluation, child: Text('Évaluation')),
            ],
            onChanged: (v) => setState(() => _selectedType = v ?? ExerciseType.training),
          ),
          const SizedBox(height: 14),

          // Format
          Text('Format Didactique', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<ExerciseFormat>(
            initialValue: _selectedFormat,
            dropdownColor: AppTheme.primaryDark,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.primaryDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: ExerciseFormat.qcm, child: Text('QCM interactif')),
              DropdownMenuItem(value: ExerciseFormat.reponseCourte, child: Text('Réponse courte')),
              DropdownMenuItem(value: ExerciseFormat.redaction, child: Text('Rédaction pas-à-pas')),
            ],
            onChanged: (v) => setState(() => _selectedFormat = v ?? ExerciseFormat.qcm),
          ),
          const SizedBox(height: 14),

          // Difficulté
          Text('Difficulté', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<ExerciseDifficulty>(
            initialValue: _selectedDifficulty,
            dropdownColor: AppTheme.primaryDark,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.primaryDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: ExerciseDifficulty.facile, child: Text('Facile (Socle)')),
              DropdownMenuItem(value: ExerciseDifficulty.intermediaire, child: Text('Intermédiaire')),
              DropdownMenuItem(value: ExerciseDifficulty.approfondissement, child: Text('Approfondissement')),
            ],
            onChanged: (v) => setState(() => _selectedDifficulty = v ?? ExerciseDifficulty.facile),
          ),
          const SizedBox(height: 14),

          // Nombre d'exercices
          Text('Nombre d\'exercices (1-10)', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.primaryDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),

          // Directives spécifiques
          Text('Consignes & Notions spécifiques (optionnel)', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ex: Insister sur les limites avec forme indéterminée 0/0 et les radicaux...',
              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: AppTheme.primaryDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 24),

          // Bouton Lancer la Génération
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isGenerating ? null : _runAiGeneration,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              _isGenerating ? 'Génération IA en cours...' : 'Générer avec l\'IA',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentRose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.4)),
              ),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_isGenerating) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.accentCyan),
              const SizedBox(height: 20),
              Text(
                'L\'agent pédagogique conçoit vos exercices...',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Résolution du contexte curriculaire, respect du Model Router zéro coût et structuration scientifique en cours.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_generatedExercises == null) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_alt_rounded, size: 56, color: AppTheme.accentCyan),
            const SizedBox(height: 18),
            Text(
              'Prêt à générer des exercices conformes au programme',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                'Configurez vos critères pédagogiques à gauche puis cliquez sur « Générer avec l\'IA » pour produire des exercices complets avec énoncés, LaTeX, QCM, corrigés et indices.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_generatedExercises!.length} Exercice(s) généré(s)',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isImporting || _selectedIndices.isEmpty
                  ? null
                  : _importSelectedExercises,
              icon: _isImporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task_rounded, size: 16),
              label: Text(
                'Importer les ${_selectedIndices.length} sélectionné(s)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < _generatedExercises!.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _buildGeneratedCard(i, _generatedExercises![i]),
        ],
      ],
    );
  }

  Widget _buildGeneratedCard(int index, Map<String, dynamic> item) {
    final isSelected = _selectedIndices.contains(index);
    final title = item['title'] as String? ?? 'Exercice sans titre';
    final statement = item['statement'] as String? ?? '';
    final options = (item['options'] as List?)?.cast<String>() ?? [];
    final correction = item['correction'] as String? ?? item['explanation'] as String? ?? '';
    final correctIndex = item['correct_index'] as int?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.accentEmerald : AppTheme.primaryBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: AppTheme.accentEmerald,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedIndices.add(index);
                    } else {
                      _selectedIndices.remove(index);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Énoncé :', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: MathText(statement, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Options QCM :', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(options.length, (optIdx) {
                final isCorrect = correctIndex == optIdx;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                        : AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect ? AppTheme.accentEmerald : AppTheme.primaryBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${String.fromCharCode(65 + optIdx)}. ',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isCorrect ? AppTheme.accentEmerald : Colors.white70),
                      ),
                      Text(
                        options[optIdx],
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
          if (correction.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Solution didactique :', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: MathText(correction, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
            ),
          ],
        ],
      ),
    );
  }
}
