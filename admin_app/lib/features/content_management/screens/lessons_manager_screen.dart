import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';

class LessonsManagerScreen extends ConsumerStatefulWidget {
  const LessonsManagerScreen({super.key});

  @override
  ConsumerState<LessonsManagerScreen> createState() =>
      _LessonsManagerScreenState();
}

class _LessonsManagerScreenState extends ConsumerState<LessonsManagerScreen> {
  String _selectedClass = 'Classe de 3ème';
  String _selectedSubject = 'Mathématiques';
  String? _selectedChapterId;

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(subjectsProvider(null));

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Leçons & Cours',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rédaction, versioning et rattachement aux Trimestres (mécanisme déblocage automatique)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showLessonEditorModal(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer une Nouvelle Leçon'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_list_rounded,
                  color: AppTheme.accentBlue,
                ),
                const SizedBox(width: 12),
                Text(
                  'Filtrer par Classe :',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedClass,
                  dropdownColor: AppTheme.primarySurface,
                  items:
                      [
                        'Classe de 3ème',
                        'Classe de 2nde',
                        'Classe de Terminale C',
                      ].map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) => setState(() => _selectedClass = val!),
                ),
                const SizedBox(width: 24),
                Text(
                  'Matière :',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                chaptersAsync.when(
                  data: (subjects) => DropdownButton<String>(
                    value: _selectedSubject,
                    dropdownColor: AppTheme.primarySurface,
                    items: subjects.map((s) {
                      return DropdownMenuItem(
                        value: s.name,
                        child: Text(
                          s.name,
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSubject = val!;
                        _selectedChapterId = null;
                      });
                    },
                  ),
                  loading: () => const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(),
                  ),
                  error: (err, _) => Text(
                    'Erreur: $err',
                    style: GoogleFonts.inter(color: AppTheme.accentRose),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Lessons Data Table
          Expanded(
            child: _selectedSubject.isEmpty
                ? Center(
                    child: Text(
                      'Sélectionnez une matière pour voir les leçons.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                : chaptersAsync.when(
                    data: (subjects) {
                      final subject = subjects.firstWhere(
                        (s) => s.name == _selectedSubject,
                        orElse: () => subjects.isNotEmpty
                            ? subjects.first
                            : Subject(id: '', name: '', code: ''),
                      );
                      return _buildLessonsTable(subject.id);
                    },
                    loading: () =>
                        const Center(child: LinearProgressIndicator()),
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

  Widget _buildLessonsTable(String subjectId) {
    return FutureBuilder<List<Lesson>>(
      future: () async {
        final service = ref.read(supabaseServiceProvider);
        final chapters = await service.fetchChapters(subjectId);
        if (chapters.isEmpty) return <Lesson>[];
        final allLessons = <Lesson>[];
        for (final chapter in chapters) {
          final lessons = await service.fetchLessonsForChapter(chapter.id);
          allLessons.addAll(lessons);
        }
        return allLessons;
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: GoogleFonts.inter(color: AppTheme.accentRose),
            ),
          );
        }

        final lessons = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppTheme.primaryDark,
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Titre de la Leçon',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Chapitre Pédagogique',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Statut',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tier Minimal',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  rows: lessons.map((lesson) {
                    final status = lesson.isPublished ? 'Publié' : 'Brouillon';
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            lesson.title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            'Chapitre ${lesson.chapterId.substring(0, 8)}',
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
                        ),
                        DataCell(_buildStatusBadge(status)),
                        DataCell(
                          Text(
                            lesson.minSubscriptionTier,
                            style: GoogleFonts.inter(
                              color: AppTheme.accentAmber,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: AppTheme.accentBlue,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility_rounded,
                                  size: 18,
                                  color: AppTheme.accentEmerald,
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    if (status == 'Publié') {
      bg = AppTheme.accentEmerald.withValues(alpha: 0.2);
      fg = AppTheme.accentEmerald;
    } else if (status == 'En attente') {
      bg = AppTheme.accentAmber.withValues(alpha: 0.2);
      fg = AppTheme.accentAmber;
    } else {
      bg = Colors.white.withValues(alpha: 0.1);
      fg = Colors.white60;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showLessonEditorModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Éditeur de Leçon (Rich Content & Médias)',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Titre de la leçon',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Trimestre de déblocage temporel',
                ),
                items: ['Trimestre 1', 'Trimestre 2', 'Trimestre 3']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText:
                      'Contenu pédagogique (Texte enrichi, formules LaTeX, médias)',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Enregistrer en Brouillon'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Soumettre pour Validation'),
          ),
        ],
      ),
    );
  }
}
