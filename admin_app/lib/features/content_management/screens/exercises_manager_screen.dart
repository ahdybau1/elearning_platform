import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';

class ExercisesManagerScreen extends ConsumerStatefulWidget {
  const ExercisesManagerScreen({super.key});

  @override
  ConsumerState<ExercisesManagerScreen> createState() =>
      _ExercisesManagerScreenState();
}

class _ExercisesManagerScreenState
    extends ConsumerState<ExercisesManagerScreen> {
  String _selectedLevelFilter = 'Tous les niveaux';

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & Action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                    ),
                    onPressed: () => _showAiGenerationModal(context),
                    icon: const Icon(Icons.psychology_rounded, size: 18),
                    label: const Text('Générer par IA (Claude)'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateExerciseModal(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Créer un Exercice'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Independence Level Tabs
          Row(
            children: [
              _buildLevelTab('Tous les niveaux'),
              const SizedBox(width: 10),
              _buildLevelTab('Niveau 1 : Leçon précise'),
              const SizedBox(width: 10),
              _buildLevelTab('Niveau 2 : Chapitre général'),
              const SizedBox(width: 10),
              _buildLevelTab('Niveau 3 : Indépendant (Type Examen)'),
            ],
          ),
          const SizedBox(height: 20),

          // Exercises Grid
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                final filtered = _filterExercises(exercises);
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
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final ex = filtered[idx];
                    return _buildExerciseCard(ex);
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

  List<Exercise> _filterExercises(List<Exercise> exercises) {
    if (_selectedLevelFilter == 'Tous les niveaux') return exercises;
    if (_selectedLevelFilter.contains('Leçon précise')) {
      return exercises.where((e) => e.lessonId != null).toList();
    }
    if (_selectedLevelFilter.contains('Chapitre général')) {
      return exercises
          .where((e) => e.chapterId != null && e.lessonId == null)
          .toList();
    }
    if (_selectedLevelFilter.contains('Indépendant')) {
      return exercises
          .where((e) => e.lessonId == null && e.chapterId == null)
          .toList();
    }
    return exercises;
  }

  Widget _buildExerciseCard(Exercise ex) {
    final typeLabel = ex.type.toString().split('.').last;
    final formatLabel = ex.format.toString().split('.').last;
    final difficultyLabel = ex.difficulty.toString().split('.').last;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBorder),
                ),
                child: Text(
                  ex.chapterId != null
                      ? 'Chapitre: ${ex.chapterId!.substring(0, 8)}'
                      : ex.lessonId != null
                      ? 'Leçon: ${ex.lessonId!.substring(0, 8)}'
                      : 'Indépendant',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
              _buildBadge(typeLabel, AppTheme.accentEmerald),
              const SizedBox(width: 8),
              _buildBadge(formatLabel, AppTheme.accentIndigo),
              const SizedBox(width: 8),
              _buildBadge(difficultyLabel, AppTheme.accentCyan),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
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

  void _showCreateExerciseModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Créer un Exercice Pédagogique',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Titre / Intitulé de l\'exercice',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Niveau d\'indépendance',
                ),
                items:
                    [
                          'Niveau 1 : Leçon précise',
                          'Niveau 2 : Chapitre général',
                          'Niveau 3 : Indépendant (Type Examen)',
                        ]
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Format de réponse',
                ),
                items:
                    [
                          'QCM',
                          'Réponse courte',
                          'Rédaction',
                          'Manuscrit scanné',
                          'Flashcard',
                        ]
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                onChanged: (v) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Enregistrer l\'exercice'),
          ),
        ],
      ),
    );
  }

  void _showAiGenerationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Row(
          children: [
            const Icon(Icons.psychology_rounded, color: AppTheme.accentCyan),
            const SizedBox(width: 8),
            Text(
              'Génération d\'Exercices par IA (Claude)',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'L\'agent IA consultera le catalogue de la matière et générera automatiquement des exercices calibrés avec énoncé et corrigé pas à pas.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Matière et Chapitre cible',
                ),
                items:
                    [
                          'Mathématiques 3e - Chapitre 1 (PGCD)',
                          'Physique 1ère - Optique',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'exercices à générer (ex: 10)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tâche asynchrone lancée. Les exercices générés sont en attente dans la File de Validation.',
                  ),
                ),
              );
            },
            child: const Text('Lancer la Génération IA'),
          ),
        ],
      ),
    );
  }
}
