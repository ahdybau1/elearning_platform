import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../widgets/media_attachment_picker.dart';
import '../utils/lesson_pdf_generator.dart';
import '../../../core/widgets/app_dialog_title.dart';

/// Types de blocs reconnus par `BlockRendererRegistry` côté `student_app` (voir
/// `docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md`, CF-002). Tenu manuellement synchronisé avec
/// `student_app/lib/core/rendering/block_renderer_registry.dart` tant qu'aucun package Dart partagé
/// n'existe entre les deux apps.
const List<(String value, String label)> kEditableBlockTypes = [
  ('paragraph', 'Paragraphe simple'),
  ('definition', 'Définition'),
  ('theoreme', 'Théorème / Propriété'),
  ('formule', 'Formule (LaTeX)'),
  ('methode', 'Méthode / Savoir-faire'),
  ('exemple', 'Exemple'),
  ('piege', 'Piège classique d\'examen'),
  ('conseil_examen', 'Conseil d\'examen'),
];

/// Bloc de contenu structuré éditable dans le formulaire admin (CF-002 partie 2). Porte ses propres
/// `TextEditingController` pour rester stable entre les rebuilds `setModalState` sans perdre le
/// curseur/la sélection en cours de frappe.
class _EditableBlock {
  String type;
  final TextEditingController headingCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController formulasCtrl;

  _EditableBlock({
    required this.type,
    String heading = '',
    String body = '',
    List<String> formulas = const [],
  }) : headingCtrl = TextEditingController(text: heading),
       bodyCtrl = TextEditingController(text: body),
       formulasCtrl = TextEditingController(text: formulas.join('\n'));

  factory _EditableBlock.fromJson(Map<String, dynamic> json) {
    final rawFormulas = json['formulas'] ?? json['latex_formulas'];
    return _EditableBlock(
      type: (json['type'] as String?)?.trim().toLowerCase().isNotEmpty == true
          ? (json['type'] as String).trim().toLowerCase()
          : 'paragraph',
      heading: (json['heading'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      formulas: rawFormulas is List
          ? rawFormulas.map((f) => f.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson(int order) {
    final formulas = formulasCtrl.text
        .split('\n')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    return {
      'type': type,
      if (headingCtrl.text.trim().isNotEmpty)
        'heading': headingCtrl.text.trim(),
      'body': bodyCtrl.text.trim(),
      'formulas': formulas,
      'order': order,
    };
  }

  bool get isEmpty =>
      bodyCtrl.text.trim().isEmpty && formulasCtrl.text.trim().isEmpty;

  void dispose() {
    headingCtrl.dispose();
    bodyCtrl.dispose();
    formulasCtrl.dispose();
  }
}

class LessonsManagerScreen extends ConsumerStatefulWidget {
  const LessonsManagerScreen({super.key});

  @override
  ConsumerState<LessonsManagerScreen> createState() =>
      _LessonsManagerScreenState();
}

class _LessonsManagerScreenState extends ConsumerState<LessonsManagerScreen> {
  String? _selectedClassNodeId;
  String? _selectedSubjectId;
  bool _showInactive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  // Mémoïse la requête de statuts de validation par liste de leçons : sans ça, un FutureBuilder
  // relançant `fetchValidationStatusForContentIds` directement dans build() repartait en réseau à
  // CHAQUE frappe dans la barre de recherche (setState sur onChanged), pas seulement quand la liste
  // de leçons affichée change réellement.
  List<String>? _lastValidationLessonIds;
  Future<Map<String, String>>? _validationStatusFuture;

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _currentAdminId() {
    return ref.read(authProvider).valueOrNull?.id ??
        '00000000-0000-0000-0000-000000000001';
  }

  bool _matchesSearch(Chapter chapter, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (chapter.title.toLowerCase().contains(q)) return true;
    return chapter.lessons.any((l) => l.title.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final classNodesAsync = ref.watch(nodesByTypeProvider('class'));
    final seriesNodesAsync = ref.watch(nodesByTypeProvider('series'));
    final classOptions = <AcademicNode>[
      ...classNodesAsync.valueOrNull ?? [],
      ...seriesNodesAsync.valueOrNull ?? [],
    ]..sort((a, b) => a.name.compareTo(b.name));

    if (_selectedClassNodeId == null && classOptions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedClassNodeId == null) {
          setState(() => _selectedClassNodeId = classOptions.first.id);
        }
      });
    } else if (_selectedClassNodeId != null &&
        !classOptions.any((n) => n.id == _selectedClassNodeId)) {
      // La classe sélectionnée a été désactivée/archivée entre-temps (Arbre Académique) :
      // sans ce filet, le DropdownButtonFormField ci-dessous planterait (value sans item
      // correspondant). On retombe sur la première classe active disponible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(
            () => _selectedClassNodeId = classOptions.isNotEmpty
                ? classOptions.first.id
                : null,
          );
        }
      });
    }

    final subjectsAsync = _selectedClassNodeId == null
        ? null
        : ref.watch(subjectsForClassProvider(_selectedClassNodeId!));
    final subjects = subjectsAsync?.valueOrNull ?? [];

    if (subjects.isNotEmpty &&
        (_selectedSubjectId == null ||
            !subjects.any((s) => s.id == _selectedSubjectId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSubjectId = subjects.first.id);
      });
    } else if (subjects.isEmpty && _selectedSubjectId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSubjectId = null);
      });
    }

    final chaptersAsync = _selectedSubjectId == null
        ? null
        : ref.watch(
            chaptersWithLessonsProvider((
              subjectId: _selectedSubjectId!,
              classNodeId: _selectedClassNodeId,
              includeInactive: _showInactive,
            )),
          );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Action Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
              ElevatedButton.icon(
                onPressed:
                    _selectedSubjectId == null || _selectedClassNodeId == null
                    ? null
                    : () => _showChapterEditorModal(
                        context,
                        _selectedSubjectId!,
                        classOptions,
                        defaultClassNodeId: _selectedClassNodeId,
                        countryId:
                            ref
                                    .read(nodesByTypeProvider('country'))
                                    .valueOrNull
                                    ?.isNotEmpty ==
                                true
                            ? ref
                                  .read(nodesByTypeProvider('country'))
                                  .valueOrNull!
                                  .first
                                  .id
                            : null,
                      ),
                icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                label: const Text('Créer un Chapitre'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      color: AppTheme.accentBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Classe :',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 220,
                      child: classOptions.isEmpty
                          ? Text(
                              'Aucune classe configurée',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentRose,
                              ),
                            )
                          // ignore: deprecated_member_use
                          : DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedClassNodeId,
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: AppTheme.primaryDark,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                              ),
                              items: classOptions
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n.id,
                                      child: Text(
                                        '${n.name}${n.code != null ? " (${n.code})" : ""}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _selectedClassNodeId = v;
                                _selectedSubjectId = null;
                              }),
                            ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Matière :',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 200,
                      child: subjects.isEmpty
                          ? Text(
                              _selectedClassNodeId == null
                                  ? '—'
                                  : 'Aucune matière liée à cette classe',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            )
                          // ignore: deprecated_member_use
                          : DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedSubjectId,
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: AppTheme.primaryDark,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                              ),
                              items: subjects
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        s.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSubjectId = v),
                            ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Rechercher un chapitre/leçon...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _showInactive,
                      activeThumbColor: AppTheme.accentAmber,
                      onChanged: (v) => setState(() => _showInactive = v),
                    ),
                    Text(
                      'Afficher les archives',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _selectedSubjectId == null
                ? Center(
                    child: Text(
                      classOptions.isEmpty
                          ? 'Configurez d\'abord l\'Arbre Académique (au moins une Classe).'
                          : 'Sélectionnez une classe puis une matière pour voir les chapitres.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                : chaptersAsync!.when(
                    data: (chapters) {
                      final visible = chapters
                          .where((c) => _matchesSearch(c, _searchQuery))
                          .toList();
                      if (chapters.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun chapitre pour cette matière. Cliquez sur "Créer un Chapitre" pour commencer.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        );
                      }
                      if (visible.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun résultat pour "$_searchQuery".',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        );
                      }
                      final allLessonIds = chapters
                          .expand((c) => c.lessons)
                          .map((l) => l.id)
                          .toList();
                      if (_validationStatusFuture == null ||
                          _lastValidationLessonIds == null ||
                          !_sameIds(_lastValidationLessonIds!, allLessonIds)) {
                        _lastValidationLessonIds = allLessonIds;
                        _validationStatusFuture = ref
                            .read(supabaseServiceProvider)
                            .fetchValidationStatusForContentIds(allLessonIds);
                      }
                      return FutureBuilder<Map<String, String>>(
                        future: _validationStatusFuture,
                        builder: (context, statusSnapshot) {
                          final statusMap = statusSnapshot.data ?? const {};
                          return Consumer(
                            builder: (context, ref, _) {
                              final countriesAsync = ref.watch(
                                nodesByTypeProvider('country'),
                              );
                              final countryId =
                                  countriesAsync.valueOrNull?.isNotEmpty == true
                                  ? countriesAsync.valueOrNull!.first.id
                                  : null;
                              final termsAsync = countryId == null
                                  ? const AsyncValue<List<Term>>.data([])
                                  : ref.watch(termsProvider(countryId));
                              final terms =
                                  List<Term>.from(
                                    termsAsync.valueOrNull ?? <Term>[],
                                  )..sort(
                                    (a, b) =>
                                        a.startDate.compareTo(b.startDate),
                                  );
                              final termNames = <String, String>{
                                for (final t in terms) t.id: t.name,
                              };
                              final subjectName = subjects
                                  .firstWhere(
                                    (s) => s.id == _selectedSubjectId,
                                    orElse: () =>
                                        Subject(id: '', name: '', code: ''),
                                  )
                                  .name;

                              // Dossiers par Trimestre (qui porte lui-même l'année scolaire) :
                              // Classe/Matière → Trimestre → Chapitre → Leçon, comme demandé —
                              // pas juste un badge, une vraie hiérarchie de dossiers dépliables.
                              final byTerm = <String?, List<Chapter>>{};
                              for (final c in visible) {
                                byTerm.putIfAbsent(c.termId, () => []).add(c);
                              }
                              final orderedTermIds = <String?>[
                                ...terms
                                    .map((t) => t.id)
                                    .where(byTerm.containsKey),
                                if (byTerm.containsKey(null)) null,
                              ];

                              return ListView.builder(
                                itemCount: orderedTermIds.length,
                                itemBuilder: (context, idx) {
                                  final termId = orderedTermIds[idx];
                                  final term = terms
                                      .where((t) => t.id == termId)
                                      .firstOrNull;
                                  final chaptersInFolder = byTerm[termId]!;
                                  return _buildTermFolder(
                                    term,
                                    chaptersInFolder,
                                    termNames,
                                    statusMap,
                                    countryId,
                                    subjectName,
                                    classOptions,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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

  /// Dossier "Trimestre" (porte l'année scolaire via term.schoolYear) regroupant les chapitres qui
  /// y sont rattachés — la hiérarchie demandée : Classe/Matière → Trimestre → Chapitre → Leçon,
  /// affichée comme de vrais dossiers dépliables plutôt qu'un simple badge sur chaque chapitre.
  Widget _buildTermFolder(
    Term? term,
    List<Chapter> chapters,
    Map<String, String> termNames,
    Map<String, String> validationStatus,
    String? countryId,
    String subjectName,
    List<AcademicNode> classOptions,
  ) {
    final folderLabel = term == null
        ? 'Sans trimestre assigné'
        : '${term.name} — Année ${term.schoolYear}';
    final activeLessonsCount = chapters.fold<int>(
      0,
      (sum, c) => sum + c.lessons.length,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: term == null
              ? AppTheme.accentAmber.withValues(alpha: 0.3)
              : AppTheme.accentIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('term-${term?.id ?? 'none'}'),
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
              Text(
                '${chapters.length} chapitre(s) • $activeLessonsCount leçon(s)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: chapters
                    .map(
                      (chapter) => _buildChapterCard(
                        chapter,
                        termNames,
                        validationStatus,
                        countryId,
                        subjectName,
                        classOptions,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard(
    Chapter chapter,
    Map<String, String> termNames,
    Map<String, String> validationStatus,
    String? countryId,
    String subjectName,
    List<AcademicNode> classOptions,
  ) {
    final termLabel = chapter.termId != null ? termNames[chapter.termId] : null;
    final className = chapter.classNodeId == null
        ? null
        : classOptions
              .where((c) => c.id == chapter.classNodeId)
              .firstOrNull
              ?.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chapter.isActive
              ? AppTheme.primaryBorder
              : AppTheme.accentAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey(chapter.id),
          initiallyExpanded: true,
          // Column plutôt que Row(Expanded(titre), badge, badge, badge, ...) : jusqu'à 5 badges à
          // largeur fixe après l'Expanded écrasaient le titre du chapitre à 1-2 caractères sur
          // mobile (retour utilisateur réel, titre tronqué à "E...", 2026-08-30).
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: chapter.isActive ? Colors.white : Colors.white38,
                  decoration: chapter.isActive
                      ? null
                      : TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: className != null
                          ? AppTheme.accentBlue.withValues(alpha: 0.15)
                          : AppTheme.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      className ?? 'Non classé',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: className != null
                            ? AppTheme.accentBlue
                            : AppTheme.accentRose,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (termLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        termLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.accentIndigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (chapter.classNodeId != null)
                    Consumer(
                      builder: (context, ref, _) {
                        final twinAsync = ref.watch(
                          twinGroupForClassProvider((
                            classNodeId: chapter.classNodeId,
                            subjectId: chapter.subjectId,
                          )),
                        );
                        final twin = twinAsync.valueOrNull;
                        final siblings =
                            twin?.members
                                .where(
                                  (m) => m.classNodeId != chapter.classNodeId,
                                )
                                .toList() ??
                            [];
                        if (siblings.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Jumelée avec : ${siblings.map((s) => s.className).join(", ")}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  if (!chapter.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ARCHIVÉ',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.accentAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    '${chapter.lessons.length} leçon(s)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          subtitle:
              chapter.introduction != null && chapter.introduction!.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    chapter.introduction!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (chapter.introMedia.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chapter.introMedia.map((m) {
                        return Chip(
                          avatar: const Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: AppTheme.accentBlue,
                          ),
                          label: Text(
                            m['filename'] as String? ??
                                m['url'] as String? ??
                                '',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: AppTheme.primaryDark,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (chapter.lessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucune leçon dans ce chapitre.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    )
                  else
                    // Une recherche qui matche le TITRE du chapitre garde toutes ses leçons
                    // visibles ; une recherche qui matche seulement des leçons (le chapitre lui-
                    // même ne matchant pas) ne montre que celles-là, sinon la recherche semble ne
                    // rien filtrer du tout à l'intérieur d'un chapitre.
                    ...(_searchQuery.isEmpty ||
                                chapter.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                )
                            ? chapter.lessons
                            : chapter.lessons
                                  .where(
                                    (l) => l.title.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                                  )
                                  .toList())
                        .map(
                          (lesson) => _buildLessonRow(
                            lesson,
                            validationStatus[lesson.id],
                            subjectName,
                            chapter.title,
                          ),
                        ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showLessonEditorModal(
                          context,
                          chapter.id,
                          chapter.lessons.length,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Ajouter une leçon ici'),
                      ),
                      TextButton.icon(
                        onPressed: () => _showChapterEditorModal(
                          context,
                          chapter.subjectId,
                          classOptions,
                          existing: chapter,
                          countryId: countryId,
                        ),
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppTheme.accentBlue,
                        ),
                        label: Text(
                          'Modifier',
                          style: GoogleFonts.inter(color: AppTheme.accentBlue),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showDuplicateChapterModal(
                          context,
                          chapter,
                          classOptions,
                        ),
                        icon: const Icon(
                          Icons.copy_all_rounded,
                          size: 16,
                          color: AppTheme.accentIndigo,
                        ),
                        label: Text(
                          'Dupliquer vers une autre classe',
                          style: GoogleFonts.inter(
                            color: AppTheme.accentIndigo,
                          ),
                        ),
                      ),
                      if (chapter.classNodeId != null)
                        Consumer(
                          builder: (context, ref, _) {
                            final twinAsync = ref.watch(
                              twinGroupForClassProvider((
                                classNodeId: chapter.classNodeId,
                                subjectId: chapter.subjectId,
                              )),
                            );
                            final twin = twinAsync.valueOrNull;
                            final siblingCount =
                                twin?.members
                                    .where(
                                      (m) =>
                                          m.classNodeId != chapter.classNodeId,
                                    )
                                    .length ??
                                0;
                            if (siblingCount == 0)
                              return const SizedBox.shrink();
                            return TextButton.icon(
                              onPressed: () => _showDuplicateToTwinGroupModal(
                                context,
                                chapter,
                                twin!,
                              ),
                              icon: const Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: AppTheme.accentCyan,
                              ),
                              label: Text(
                                'Dupliquer vers les classes jumelées ($siblingCount)',
                                style: GoogleFonts.inter(
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            );
                          },
                        ),
                      TextButton.icon(
                        onPressed: () => chapter.isActive
                            ? _showDeactivateChapterConfirmation(
                                context,
                                chapter,
                              )
                            : _showReactivateChapterConfirmation(
                                context,
                                chapter,
                              ),
                        icon: Icon(
                          chapter.isActive
                              ? Icons.archive_rounded
                              : Icons.unarchive_rounded,
                          size: 16,
                          color: AppTheme.accentAmber,
                        ),
                        label: Text(
                          chapter.isActive
                              ? 'Archiver ce chapitre'
                              : 'Désarchiver ce chapitre',
                          style: GoogleFonts.inter(color: AppTheme.accentAmber),
                        ),
                      ),
                      if (!chapter.isActive)
                        TextButton.icon(
                          onPressed: () =>
                              _showPermanentDeleteChapterConfirmation(
                                context,
                                chapter,
                              ),
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            size: 16,
                            color: AppTheme.accentRose,
                          ),
                          label: Text(
                            'Supprimer définitivement',
                            style: GoogleFonts.inter(
                              color: AppTheme.accentRose,
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
      ),
    );
  }

  Widget _buildLessonRow(
    Lesson lesson,
    String? validationStatus,
    String subjectName,
    String chapterTitle,
  ) {
    final titleAndBadges = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: lesson.isActive ? Colors.white : Colors.white38,
              decoration: lesson.isActive ? null : TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildLessonStatusBadge(lesson, validationStatus),
              _buildTierBadge(lesson.minSubscriptionTier),
            ],
          ),
        ],
      ),
    );

    final actionButtons = [
      IconButton(
        icon: const Icon(
          Icons.history_rounded,
          size: 18,
          color: AppTheme.accentCyan,
        ),
        tooltip: 'Historique des versions',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _showLessonVersionHistoryModal(context, lesson),
      ),
      IconButton(
        icon: const Icon(
          Icons.visibility_rounded,
          size: 18,
          color: AppTheme.accentEmerald,
        ),
        tooltip: 'Aperçu',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _showLessonPreviewModal(
          context,
          title: lesson.title,
          tier: lesson.minSubscriptionTier,
          body: lesson.contentJson['body'] as String? ?? '',
          media: List<Map<String, dynamic>>.from(
            (lesson.contentJson['media'] as List?) ?? [],
          ),
          blocks: _resolveBlocksForPreview(lesson.contentJson),
          subjectName: subjectName,
          chapterTitle: chapterTitle,
        ),
      ),
      IconButton(
        icon: const Icon(
          Icons.picture_as_pdf_rounded,
          size: 18,
          color: AppTheme.accentRose,
        ),
        tooltip: 'Imprimer / Exporter en PDF',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => LessonPdfGenerator.printOrSave(
          lesson: lesson,
          subjectName: subjectName,
          chapterTitle: chapterTitle,
        ),
      ),
      IconButton(
        icon: const Icon(
          Icons.edit_rounded,
          size: 18,
          color: AppTheme.accentBlue,
        ),
        tooltip: 'Modifier',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _showLessonEditorModal(
          context,
          lesson.chapterId,
          lesson.displayOrder,
          existing: lesson,
        ),
      ),
      IconButton(
        icon: Icon(
          lesson.isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
          size: 18,
          color: AppTheme.accentAmber,
        ),
        tooltip: lesson.isActive ? 'Archiver' : 'Désarchiver',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => lesson.isActive
            ? _showDeactivateLessonConfirmation(context, lesson)
            : _showReactivateLessonConfirmation(context, lesson),
      ),
      if (!lesson.isActive)
        IconButton(
          icon: const Icon(
            Icons.delete_forever_rounded,
            size: 18,
            color: AppTheme.accentRose,
          ),
          tooltip: 'Supprimer définitivement',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () =>
              _showPermanentDeleteLessonConfirmation(context, lesson),
        ),
    ];

    final leadingIcon = Icon(
      lesson.isActive ? Icons.menu_book_rounded : Icons.visibility_off_rounded,
      size: 18,
      color: lesson.isActive ? AppTheme.accentBlue : Colors.white24,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      // Column plutôt que Row(icône, Expanded(titre+badges), 5-6 IconButton) : les boutons
      // d'action à largeur fixe affamaient le titre+badges sur mobile jusqu'à quelques pixels de
      // large (retour utilisateur réel, badge "Publiée" écrit à la verticale lettre par lettre,
      // 2026-08-30). Sous 700px, titre+badges passent en pleine largeur et les boutons se
      // regroupent dans un Wrap en dessous.
      child: Builder(
        builder: (context) {
          if (MediaQuery.of(context).size.width < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leadingIcon,
                    const SizedBox(width: 12),
                    titleAndBadges,
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 2, runSpacing: 2, children: actionButtons),
              ],
            );
          }
          return Row(
            children: [
              leadingIcon,
              const SizedBox(width: 12),
              titleAndBadges,
              const SizedBox(width: 8),
              ...actionButtons,
            ],
          );
        },
      ),
    );
  }

  Widget _buildLessonStatusBadge(Lesson lesson, String? validationStatus) {
    String label;
    Color color;
    if (!lesson.isActive) {
      label = 'Archivée';
      color = Colors.white38;
    } else if (lesson.isPublished) {
      label = 'Publiée';
      color = AppTheme.accentEmerald;
    } else {
      switch (validationStatus) {
        case 'en_attente':
          label = 'En attente de validation';
          color = AppTheme.accentAmber;
          break;
        case 'a_corriger':
          label = 'À corriger';
          color = AppTheme.accentAmber;
          break;
        case 'rejete':
          label = 'Rejetée';
          color = AppTheme.accentRose;
          break;
        default:
          label = 'Brouillon';
          color = Colors.white60;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentIndigo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tier,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppTheme.accentIndigo,
        ),
      ),
    );
  }

  /// Dialogue de confirmation générique pour les 6 actions archiver/désarchiver/supprimer
  /// définitivement (chapitres et leçons) : évite de dupliquer 6 fois la même structure
  /// showDialog/StatefulBuilder/AlertDialog. Quand [typedConfirmationTarget] est fourni, le bouton
  /// de confirmation reste désactivé tant que le texte tapé n'y correspond pas exactement — réservé
  /// aux suppressions définitives.
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: icon,
            iconColor: iconColor,
            text: title,
            onClose: () => Navigator.pop(ctx),
          ),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: typedController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: typedConfirmationTarget,
                        prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                      ),
                      onChanged: (v) => setModalState(
                        () => matches = v.trim() == typedConfirmationTarget,
                      ),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.accentRose.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.accentRose,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentRose,
                                height: 1.4,
                              ),
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
                        ref.invalidate(chaptersWithLessonsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentEmerald,
                            content: Text(successMessage),
                          ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateChapterConfirmation(
    BuildContext context,
    Chapter chapter,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.archive_rounded,
      iconColor: AppTheme.accentAmber,
      title: 'Archiver "${chapter.title}" ?',
      content: Text(
        'Ce chapitre ET ses ${chapter.lessons.length} leçon(s) seront masqués aux élèves (pas '
        'supprimés — vous pourrez les désarchiver ou les supprimer définitivement plus tard).',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      confirmLabel: 'Archiver',
      confirmColor: AppTheme.accentAmber,
      onConfirm: () =>
          service.deactivateChapterCascade(chapter.id, _currentAdminId()),
      successMessage: 'Chapitre "${chapter.title}" et ses leçons archivés.',
    );
  }

  void _showReactivateChapterConfirmation(
    BuildContext context,
    Chapter chapter,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.unarchive_rounded,
      iconColor: AppTheme.accentEmerald,
      title: 'Désarchiver "${chapter.title}" ?',
      content: Text(
        'Ce chapitre ET toutes ses leçons redeviendront actifs et visibles (un simple "Modifier" '
        'ne désarchive que le chapitre seul, pas ses leçons).',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      confirmLabel: 'Désarchiver',
      confirmColor: AppTheme.accentEmerald,
      onConfirm: () =>
          service.reactivateChapterCascade(chapter.id, _currentAdminId()),
      successMessage: 'Chapitre "${chapter.title}" et ses leçons désarchivés.',
    );
  }

  void _showPermanentDeleteChapterConfirmation(
    BuildContext context,
    Chapter chapter,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppTheme.accentRose,
      title: 'Supprimer définitivement "${chapter.title}" ?',
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
        ),
        child: Text(
          'IRRÉVERSIBLE : ce chapitre, ses ${chapter.lessons.length} leçon(s), leurs versions et '
          'tous les exercices qui leur sont rattachés seront physiquement supprimés de la base.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.accentRose,
            height: 1.4,
          ),
        ),
      ),
      confirmLabel: 'Supprimer définitivement',
      confirmColor: AppTheme.accentRose,
      onConfirm: () =>
          service.permanentlyDeleteChapter(chapter.id, _currentAdminId()),
      successMessage: 'Chapitre "${chapter.title}" supprimé définitivement.',
      typedConfirmationTarget: chapter.title,
    );
  }

  void _showDeactivateLessonConfirmation(BuildContext context, Lesson lesson) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.archive_rounded,
      iconColor: AppTheme.accentAmber,
      title: 'Archiver "${lesson.title}" ?',
      content: Text(
        'Cette leçon sera masquée aux élèves, pas supprimée — vous pourrez la désarchiver ou la '
        'supprimer définitivement plus tard.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      confirmLabel: 'Archiver',
      confirmColor: AppTheme.accentAmber,
      onConfirm: () => service.updateLesson(id: lesson.id, isActive: false),
      successMessage: 'Leçon "${lesson.title}" archivée.',
    );
  }

  void _showReactivateLessonConfirmation(BuildContext context, Lesson lesson) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.unarchive_rounded,
      iconColor: AppTheme.accentEmerald,
      title: 'Désarchiver "${lesson.title}" ?',
      content: Text(
        'Cette leçon redeviendra active et visible dans l\'application.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      confirmLabel: 'Désarchiver',
      confirmColor: AppTheme.accentEmerald,
      onConfirm: () => service.updateLesson(id: lesson.id, isActive: true),
      successMessage: 'Leçon "${lesson.title}" désarchivée.',
    );
  }

  void _showPermanentDeleteLessonConfirmation(
    BuildContext context,
    Lesson lesson,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppTheme.accentRose,
      title: 'Supprimer définitivement "${lesson.title}" ?',
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
        ),
        child: Text(
          'IRRÉVERSIBLE : cette leçon, ses versions et les exercices qui lui sont rattachés seront '
          'physiquement supprimés de la base.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.accentRose,
            height: 1.4,
          ),
        ),
      ),
      confirmLabel: 'Supprimer définitivement',
      confirmColor: AppTheme.accentRose,
      onConfirm: () =>
          service.permanentlyDeleteLesson(lesson.id, _currentAdminId()),
      successMessage: 'Leçon "${lesson.title}" supprimée définitivement.',
      typedConfirmationTarget: lesson.title,
    );
  }

  void _showChapterEditorModal(
    BuildContext context,
    String subjectId,
    List<AcademicNode> classOptions, {
    Chapter? existing,
    String? countryId,
    String? defaultClassNodeId,
  }) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final introController = TextEditingController(
      text: existing?.introduction ?? '',
    );
    String? selectedTermId = existing?.termId;
    String? selectedClassNodeId = existing?.classNodeId ?? defaultClassNodeId;
    List<MediaAsset> attachedIntroMedia = (existing?.introMedia ?? [])
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
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dialogWidth = MediaQuery.of(context).size.width * 0.85;
          return AlertDialog(
            backgroundColor: AppTheme.primarySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: AppDialogTitle(
              icon: isEditing
                  ? Icons.edit_rounded
                  : Icons.create_new_folder_rounded,
              iconColor: AppTheme.accentEmerald,
              text: isEditing ? 'Modifier le Chapitre' : 'Nouveau Chapitre',
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
                        onPressed: () => _previewChapterDraftAsPdf(
                          subjectId: subjectId,
                          title: titleController.text.trim(),
                          introduction: introController.text.trim(),
                          media: attachedIntroMedia,
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                        ),
                        label: const Text('Aperçu PDF'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                        ),
                        onPressed: () => _showChapterStudentPreviewModal(
                          context,
                          title: titleController.text.trim().isEmpty
                              ? '(Sans titre)'
                              : titleController.text.trim(),
                          className: classOptions
                              .where((c) => c.id == selectedClassNodeId)
                              .firstOrNull
                              ?.name,
                          termLabel: selectedTermId == null
                              ? null
                              : (countryId == null
                                    ? null
                                    : ref
                                          .read(termsProvider(countryId))
                                          .valueOrNull
                                          ?.where((t) => t.id == selectedTermId)
                                          .firstOrNull
                                          ?.name),
                          introduction: introController.text.trim(),
                          media: attachedIntroMedia,
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
                                    labelText: 'Titre du chapitre',
                                    prefixIcon: Icon(
                                      Icons.title_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                ),
                                const SizedBox(height: 16),
                                // ignore: deprecated_member_use
                                DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: selectedClassNodeId,
                                  dropdownColor: AppTheme.primaryDark,
                                  style: const TextStyle(color: Colors.white),
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Classe / Série',
                                    helperText:
                                        selectedClassNodeId != null &&
                                            !classOptions.any(
                                              (c) =>
                                                  c.id == selectedClassNodeId,
                                            )
                                        ? 'Cette classe a été archivée depuis l\'Arbre Académique — choisissez-en une active'
                                        : 'Ce chapitre n\'est visible que dans cette classe',
                                    helperMaxLines: 2,
                                    prefixIcon: const Icon(
                                      Icons.school_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  items: [
                                    ...classOptions.map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // La classe actuellement rattachée peut avoir été archivée entre-temps
                                    // (Arbre Académique) : sans cette entrée, `value` ne correspondrait à
                                    // aucun `item` et le dropdown planterait à l'ouverture du formulaire.
                                    if (selectedClassNodeId != null &&
                                        !classOptions.any(
                                          (c) => c.id == selectedClassNodeId,
                                        ))
                                      DropdownMenuItem(
                                        value: selectedClassNodeId,
                                        child: Text(
                                          'Classe archivée (id: ${selectedClassNodeId!.substring(0, 8)}…)',
                                          style: const TextStyle(
                                            color: AppTheme.accentAmber,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setModalState(
                                    () => selectedClassNodeId = v,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final termsAsync = countryId == null
                                        ? const AsyncValue<List<Term>>.data([])
                                        : ref.watch(termsProvider(countryId));
                                    return termsAsync.when(
                                      data: (terms) => Row(
                                        children: [
                                          Expanded(
                                            // ignore: deprecated_member_use
                                            child: DropdownButtonFormField<String?>(
                                              // ignore: deprecated_member_use
                                              value: selectedTermId,
                                              dropdownColor:
                                                  AppTheme.primaryDark,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Trimestre (optionnel)',
                                                prefixIcon: Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 20,
                                                ),
                                              ),
                                              items: [
                                                const DropdownMenuItem<String?>(
                                                  value: null,
                                                  child: Text(
                                                    'Aucun trimestre spécifique',
                                                  ),
                                                ),
                                                // Les trimestres archivés ne doivent pas pouvoir être
                                                // choisis pour du nouveau contenu, mais celui déjà
                                                // sélectionné doit rester visible (sinon le dropdown
                                                // planterait en édition d'un chapitre existant).
                                                ...terms
                                                    .where(
                                                      (t) =>
                                                          t.isActive ||
                                                          t.id ==
                                                              selectedTermId,
                                                    )
                                                    .map(
                                                      (
                                                        t,
                                                      ) => DropdownMenuItem<String?>(
                                                        value: t.id,
                                                        child: Text(
                                                          t.isActive
                                                              ? '${t.name} (${t.schoolYear})'
                                                              : '${t.name} (${t.schoolYear}) — archivé',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                              ],
                                              onChanged: (v) => setModalState(
                                                () => selectedTermId = v,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline_rounded,
                                              color: AppTheme.accentEmerald,
                                            ),
                                            tooltip: 'Créer un trimestre',
                                            onPressed: countryId == null
                                                ? null
                                                : () => _showCreateTermModal(
                                                    context,
                                                    countryId,
                                                    (created) {
                                                      setModalState(
                                                        () => selectedTermId =
                                                            created.id,
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                      loading: () =>
                                          const LinearProgressIndicator(),
                                      error: (err, _) => Text(
                                        'Erreur trimestres: $err',
                                        style: GoogleFonts.inter(
                                          color: AppTheme.accentRose,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        const VerticalDivider(
                          width: 1,
                          color: AppTheme.primaryBorder,
                        ),
                        const SizedBox(width: 24),
                        // Colonne droite : contenu
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: introController,
                                  maxLines: 10,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Introduction (aperçu visible avant abonnement)',
                                    prefixIcon: Icon(
                                      Icons.notes_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: MediaAttachmentPicker(
                                    initialAssets: attachedIntroMedia,
                                    onChanged: (assets) =>
                                        attachedIntroMedia = assets,
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
                child: Text(
                  'Annuler',
                  style: GoogleFonts.inter(color: AppTheme.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          setModalState(
                            () => submitError = 'Le titre est obligatoire.',
                          );
                          return;
                        }
                        if (selectedClassNodeId == null) {
                          setModalState(
                            () => submitError =
                                'La classe/série est obligatoire.',
                          );
                          return;
                        }
                        setModalState(() {
                          submitError = null;
                          isLoading = true;
                        });
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          final introMediaPayload = attachedIntroMedia
                              .map(
                                (a) => {
                                  'url': a.url,
                                  'filename': a.filename,
                                  'type': a.type,
                                },
                              )
                              .toList();
                          if (isEditing) {
                            await service.updateChapter(
                              existing.id,
                              title: title,
                              introduction: introController.text.trim(),
                              introMedia: introMediaPayload,
                              updateTermId: true,
                              termId: selectedTermId,
                              updateClassNodeId: true,
                              classNodeId: selectedClassNodeId,
                            );
                          } else {
                            await service.createChapter(
                              subjectId: subjectId,
                              classNodeId: selectedClassNodeId,
                              title: title,
                              introduction: introController.text.trim().isEmpty
                                  ? null
                                  : introController.text.trim(),
                              introMedia: introMediaPayload,
                              termId: selectedTermId,
                              displayOrder: 0,
                            );
                          }
                          ref.invalidate(chaptersWithLessonsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.accentEmerald,
                                content: Text(
                                  isEditing
                                      ? 'Chapitre "$title" mis à jour.'
                                      : 'Chapitre "$title" créé.',
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? 'Enregistrer' : 'Créer le chapitre'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Génère un PDF d'aperçu à partir de l'état courant du formulaire chapitre (pas encore
  /// enregistré) — réutilise LessonPdfGenerator en enveloppant l'introduction dans un `Lesson`
  /// jetable (un chapitre n'a pas de générateur PDF dédié, inutile d'en écrire un second).
  Future<void> _previewChapterDraftAsPdf({
    required String subjectId,
    required String title,
    required String introduction,
    required List<MediaAsset> media,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    final subject = await service.getSubject(subjectId);
    final draft = Lesson(
      id: 'apercu',
      chapterId: 'apercu',
      title: title.isEmpty ? '(Sans titre)' : title,
      contentJson: {
        'body': introduction,
        'media': media
            .map((a) => {'url': a.url, 'filename': a.filename, 'type': a.type})
            .toList(),
      },
    );
    await LessonPdfGenerator.printOrSave(
      lesson: draft,
      subjectName: subject?.name ?? 'Matière',
      chapterTitle: 'Introduction de chapitre',
    );
  }

  /// Maquette illustrative de l'affichage du chapitre côté application élève — même style que
  /// l'aperçu élève des Exercices, pour rester cohérent visuellement dans tout le module Contenu.
  void _showChapterStudentPreviewModal(
    BuildContext context, {
    required String title,
    required String? className,
    required String? termLabel,
    required String introduction,
    required List<MediaAsset> media,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5FA),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
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
                    const Icon(
                      Icons.smartphone_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aperçu — Application Élève',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
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
                          if (className != null)
                            _studentBadge(className, const Color(0xFF1E3A8A)),
                          if (termLabel != null)
                            _studentBadge(termLabel, const Color(0xFF7C3AED)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        introduction.isEmpty
                            ? 'Aucune introduction rédigée pour le moment.'
                            : introduction,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                      if (media.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: media
                              .map(
                                (m) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.attach_file_rounded,
                                        size: 14,
                                        color: Color(0xFF4B5563),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        m.filename,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Les leçons de ce chapitre s\'affichent séparément, sous cette introduction.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aperçu illustratif — le rendu réel dans l\'application élève pourra différer légèrement.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _studentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showDuplicateChapterModal(
    BuildContext context,
    Chapter chapter,
    List<AcademicNode> classOptions,
  ) {
    final targets = classOptions
        .where((c) => c.id != chapter.classNodeId)
        .toList();
    if (targets.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.block_rounded,
            text: 'Duplication impossible',
            onClose: () => Navigator.pop(ctx),
          ),
          content: Text(
            'Aucune autre classe/série disponible pour la duplication.',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    String? targetClassNodeId;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.copy_all_rounded,
            iconColor: AppTheme.accentIndigo,
            text: 'Dupliquer "${chapter.title}"',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pour les programmes identiques entre classes/séries (ex: séries jumelées). '
                    'Le chapitre et ses leçons seront copiés — les deux versions restent ensuite '
                    'indépendantes : modifier l\'une ne change pas l\'autre.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: targetClassNodeId,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Classe / Série cible',
                    ),
                    items: targets
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => targetClassNodeId = v),
                  ),
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
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentIndigo,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (targetClassNodeId == null) {
                        setModalState(
                          () => submitError = 'Sélectionnez une classe cible.',
                        );
                        return;
                      }
                      setModalState(() {
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.duplicateChapterToClass(
                          chapterId: chapter.id,
                          targetClassNodeId: targetClassNodeId!,
                          adminId: _currentAdminId(),
                        );
                        ref.invalidate(chaptersWithLessonsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                '"${chapter.title}" dupliqué avec succès.',
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Dupliquer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Duplique un chapitre vers TOUTES les classes de son groupe jumelé en un seul clic, avec
  /// aperçu du nombre de leçons/exercices concernés — évite à l'admin de devoir répéter
  /// manuellement "Dupliquer vers une autre classe" pour chaque classe jumelée, une par une.
  void _showDuplicateToTwinGroupModal(
    BuildContext context,
    Chapter chapter,
    TwinGroup twin,
  ) {
    final siblings = twin.members
        .where((m) => m.classNodeId != chapter.classNodeId)
        .toList();
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.link_rounded,
            iconColor: AppTheme.accentCyan,
            text: 'Dupliquer "${chapter.title}" vers les classes jumelées',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ce chapitre sera dupliqué (avec ses leçons et exercices) vers :',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: siblings
                      .map(
                        (s) => Chip(
                          label: Text(
                            s.className,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: AppTheme.accentCyan.withValues(
                            alpha: 0.15,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final impactAsync = ref.watch(
                      chapterDuplicationImpactProvider(chapter.id),
                    );
                    return impactAsync.when(
                      data: (impact) => Text(
                        '${impact.lessonCount} leçon(s) et ${impact.exerciseCount} exercice(s) seront dupliqués '
                        'vers chacune des ${siblings.length} classe(s) ci-dessus.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text(
                        'Erreur: $err',
                        style: GoogleFonts.inter(
                          color: AppTheme.accentRose,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: errorText!),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() {
                        errorText = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        final results = await service
                            .duplicateChapterToTwinGroup(
                              chapter.id,
                              _currentAdminId(),
                            );
                        ref.invalidate(chaptersWithLessonsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                '"${chapter.title}" dupliqué vers ${results.length} classe(s) jumelée(s).',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Dupliquer vers toutes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTermModal(
    BuildContext context,
    String countryId,
    void Function(Term created) onCreated,
  ) {
    final nameController = TextEditingController();
    final schoolYearController = TextEditingController(text: '2026-2027');
    DateTime? startDate;
    DateTime? endDate;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.calendar_month_rounded,
            text: 'Créer un Trimestre',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nom (ex: Trimestre 1)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: schoolYearController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Année scolaire (ex: 2026-2027)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (picked != null)
                              setModalState(() => startDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(
                            startDate == null
                                ? 'Début'
                                : startDate!.toString().split(' ').first,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (picked != null)
                              setModalState(() => endDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(
                            endDate == null
                                ? 'Fin'
                                : endDate!.toString().split(' ').first,
                          ),
                        ),
                      ),
                    ],
                  ),
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
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final schoolYear = schoolYearController.text.trim();
                      if (name.isEmpty ||
                          schoolYear.isEmpty ||
                          startDate == null ||
                          endDate == null) {
                        setModalState(
                          () => submitError =
                              'Tous les champs sont obligatoires.',
                        );
                        return;
                      }
                      setModalState(() {
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        final created = await service.createTerm(
                          countryId: countryId,
                          name: name,
                          startDate: startDate!,
                          endDate: endDate!,
                          schoolYear: schoolYear,
                        );
                        ref.invalidate(termsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (created != null) onCreated(created);
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLessonEditorModal(
    BuildContext context,
    String chapterId,
    int nextDisplayOrder, {
    Lesson? existing,
  }) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(
      text: existing?.contentJson['body'] as String? ?? '',
    );
    String selectedTier = existing?.minSubscriptionTier ?? 'gratuit';
    List<MediaAsset> attachedMedia =
        ((existing?.contentJson['media'] as List?) ?? [])
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
    Map<String, dynamic>? aiStructured =
        (existing?.contentJson['ai_structured'] as Map?)
            ?.cast<String, dynamic>();
    // Blocs de contenu éditables (CF-002 partie 2) : pré-remplis depuis content_json['blocks']
    // (format natif) si présent, sinon dérivés de ai_structured, sinon — pour une très ancienne leçon
    // enregistrée avant la structuration IA — un unique bloc paragraphe repris du texte brut.
    final List<_EditableBlock> blocks = isEditing
        ? _resolveBlocksForPreview(
            existing.contentJson,
          ).map((b) => _EditableBlock.fromJson(b)).toList()
        : <_EditableBlock>[];
    if (blocks.isEmpty && isEditing) {
      final legacyBody = existing.contentJson['body'] as String?;
      if (legacyBody != null && legacyBody.trim().isNotEmpty) {
        blocks.add(_EditableBlock(type: 'paragraph', body: legacyBody.trim()));
      }
    }
    // Nouvelle leçon : un bloc paragraphe vide prêt à l'emploi, pour ne pas forcer un clic
    // supplémentaire sur "Ajouter un bloc" avant de pouvoir taper du contenu.
    if (blocks.isEmpty && !isEditing) {
      blocks.add(_EditableBlock(type: 'paragraph'));
    }
    String? submitError;
    bool isLoading = false;
    bool isGeneratingAi = false;
    String? resolvedChapterTitle;
    String? resolvedSubjectName;
    bool hasStartedContextFetch = false;
    // Suit une éventuelle création déjà réussie dans CETTE ouverture du formulaire : si
    // createLesson() réussit mais que submitOrAutoApprove() échoue ensuite (réseau, etc.), un
    // nouveau clic sur "Enregistrer" ne doit PAS recréer une deuxième leçon en double — juste
    // retenter la soumission sur celle déjà insérée.
    String? createdLessonId = existing?.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!hasStartedContextFetch) {
            hasStartedContextFetch = true;
            final service = ref.read(supabaseServiceProvider);
            service.getChapter(chapterId).then((chapter) async {
              if (chapter == null) return;
              final subject = await service.getSubject(chapter.subjectId);
              resolvedChapterTitle = chapter.title;
              resolvedSubjectName = subject?.name;
              setModalState(() {});
            });
          }
          final dialogWidth = MediaQuery.of(context).size.width * 0.85;
          return AlertDialog(
            backgroundColor: AppTheme.primarySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: AppDialogTitle(
              icon: Icons.menu_book_rounded,
              text: isEditing
                  ? 'Modifier la Leçon'
                  : 'Éditeur de Leçon (Conforme au Programme)',
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
                        onPressed: () => LessonPdfGenerator.printOrSave(
                          lesson: Lesson(
                            id: existing?.id ?? 'apercu',
                            chapterId: chapterId,
                            title: titleController.text.trim().isEmpty
                                ? '(Sans titre)'
                                : titleController.text.trim(),
                            minSubscriptionTier: selectedTier,
                            contentJson: {
                              'body': contentController.text.trim(),
                              'media': attachedMedia
                                  .map(
                                    (a) => {
                                      'url': a.url,
                                      'filename': a.filename,
                                      'type': a.type,
                                    },
                                  )
                                  .toList(),
                              'ai_structured': ?aiStructured,
                              'blocks': [
                                for (var i = 0; i < blocks.length; i++)
                                  blocks[i].toJson(i),
                              ],
                            },
                          ),
                          subjectName: resolvedSubjectName ?? 'Matière',
                          chapterTitle: resolvedChapterTitle ?? 'Chapitre',
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                        ),
                        label: const Text('Aperçu PDF'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                        ),
                        onPressed: () => _showLessonPreviewModal(
                          context,
                          title: titleController.text.trim().isEmpty
                              ? '(Sans titre)'
                              : titleController.text.trim(),
                          tier: selectedTier,
                          body: contentController.text.trim(),
                          media: attachedMedia
                              .map(
                                (a) => {
                                  'url': a.url,
                                  'filename': a.filename,
                                  'type': a.type,
                                },
                              )
                              .toList(),
                          blocks: [
                            for (var i = 0; i < blocks.length; i++)
                              blocks[i].toJson(i),
                          ],
                          subjectName: resolvedSubjectName ?? 'Matière',
                          chapterTitle: resolvedChapterTitle ?? 'Chapitre',
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
                        // Colonne gauche : classification / contexte
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
                                    labelText: 'Titre de la leçon',
                                    prefixIcon: Icon(
                                      Icons.title_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // ignore: deprecated_member_use
                                DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: selectedTier,
                                  dropdownColor: AppTheme.primaryDark,
                                  style: const TextStyle(color: Colors.white),
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Niveau d\'accès requis',
                                    prefixIcon: Icon(
                                      Icons.lock_open_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'gratuit',
                                      child: Text('Gratuit (Accès libre)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'journalier',
                                      child: Text('Journalier (Restreint)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'mensuel',
                                      child: Text('Mensuel (Premium)'),
                                    ),
                                  ],
                                  onChanged: (v) => setModalState(
                                    () => selectedTier = v ?? 'gratuit',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Contexte',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.folder_rounded,
                                        size: 14,
                                        color: AppTheme.accentIndigo,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          resolvedChapterTitle ??
                                              'Résolution du chapitre…',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.menu_book_rounded,
                                        size: 14,
                                        color: AppTheme.accentBlue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          resolvedSubjectName ??
                                              'Résolution de la matière…',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        const VerticalDivider(
                          width: 1,
                          color: AppTheme.primaryBorder,
                        ),
                        const SizedBox(width: 24),
                        // Colonne droite : contenu
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: contentController,
                                  maxLines: 4,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Notes brutes / mots-clés',
                                    helperText:
                                        'Optionnel — point de départ pour la génération IA ci-dessous',
                                    alignLabelWithHint: true,
                                    prefixIcon: Icon(
                                      Icons.article_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.accentCyan,
                                    ),
                                    onPressed: isGeneratingAi
                                        ? null
                                        : () async {
                                            if (contentController.text
                                                .trim()
                                                .isEmpty) {
                                              setModalState(
                                                () => submitError =
                                                    'Saisissez quelques notes/mots-clés avant de générer.',
                                              );
                                              return;
                                            }
                                            setModalState(() {
                                              isGeneratingAi = true;
                                              submitError = null;
                                            });
                                            try {
                                              final service = ref.read(
                                                supabaseServiceProvider,
                                              );
                                              final result = await service
                                                  .generateAiLessonDraft(
                                                    chapterId: chapterId,
                                                    rawNotes: contentController
                                                        .text
                                                        .trim(),
                                                  );
                                              setModalState(() {
                                                aiStructured = result;
                                                isGeneratingAi = false;
                                                if (titleController.text
                                                        .trim()
                                                        .isEmpty &&
                                                    result['title'] != null) {
                                                  titleController.text =
                                                      result['title'] as String;
                                                }
                                                // Remplace les blocs par la structuration IA — l'admin
                                                // reste libre de les modifier/supprimer un par un ensuite
                                                // (voir CF-002, blocs éditables ci-dessous).
                                                final generated =
                                                    _blocksFromAiStructured(
                                                      result,
                                                    ) ??
                                                    const [];
                                                for (final b in blocks) {
                                                  b.dispose();
                                                }
                                                blocks
                                                  ..clear()
                                                  ..addAll(
                                                    generated.map(
                                                      _EditableBlock.fromJson,
                                                    ),
                                                  );
                                              });
                                            } catch (e) {
                                              setModalState(() {
                                                isGeneratingAi = false;
                                                submitError = 'Erreur IA : $e';
                                              });
                                            }
                                          },
                                    icon: isGeneratingAi
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.accentCyan,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.psychology_rounded,
                                            size: 16,
                                          ),
                                    label: Text(
                                      isGeneratingAi
                                          ? 'Génération en cours...'
                                          : (blocks.isEmpty
                                                ? 'Structurer avec l\'IA (Gemini)'
                                                : 'Regénérer avec l\'IA (remplace les blocs ci-dessous)'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Divider(
                                  height: 1,
                                  color: AppTheme.primaryBorder,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Blocs de contenu',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Chaque bloc a un type (icône/couleur propre côté élève) — ajoutez, réordonnez ou '
                                  'supprimez librement. La génération IA les remplit, mais tout reste modifiable à la main.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (blocks.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryDark,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.primaryBorder,
                                      ),
                                    ),
                                    child: Text(
                                      'Aucun bloc pour l\'instant — générez avec l\'IA ci-dessus ou ajoutez un bloc manuellement.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  )
                                else
                                  for (var i = 0; i < blocks.length; i++)
                                    _buildEditableBlockCard(
                                      blocks[i],
                                      index: i,
                                      isFirst: i == 0,
                                      isLast: i == blocks.length - 1,
                                      onTypeChanged: () => setModalState(() {}),
                                      onMoveUp: () => setModalState(() {
                                        final b = blocks.removeAt(i);
                                        blocks.insert(i - 1, b);
                                      }),
                                      onMoveDown: () => setModalState(() {
                                        final b = blocks.removeAt(i);
                                        blocks.insert(i + 1, b);
                                      }),
                                      onDelete: () => setModalState(
                                        () => blocks.removeAt(i).dispose(),
                                      ),
                                    ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.accentIndigo,
                                    ),
                                    onPressed: () => setModalState(
                                      () => blocks.add(
                                        _EditableBlock(type: 'paragraph'),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Ajouter un bloc'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: MediaAttachmentPicker(
                                    initialAssets: attachedMedia,
                                    onChanged: (assets) =>
                                        attachedMedia = assets,
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
                child: Text(
                  'Annuler',
                  style: GoogleFonts.inter(color: AppTheme.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          setModalState(
                            () => submitError = 'Le titre est obligatoire.',
                          );
                          return;
                        }

                        setModalState(() {
                          submitError = null;
                          isLoading = true;
                        });
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          // Format natif "blocks" (CF-001/CF-002, docs/CONTENT_FACTORY_IMPLEMENTATION_
                          // PLAN.md) — c'est désormais la véritable source de vérité éditée à la main,
                          // que la structuration IA ait servi de point de départ ou non. `body` reste
                          // dérivé (concaténation des contenus des blocs) pour la compatibilité des
                          // écrans/exports qui ne connaissent pas encore `blocks`.
                          final blocksJson = [
                            for (var i = 0; i < blocks.length; i++)
                              if (!blocks[i].isEmpty) blocks[i].toJson(i),
                          ];
                          final derivedBody = blocksJson
                              .map((b) => b['body'] as String)
                              .where((s) => s.isNotEmpty)
                              .join('\n\n');
                          final contentJson = {
                            'body': derivedBody,
                            'media': attachedMedia
                                .map(
                                  (a) => {
                                    'url': a.url,
                                    'filename': a.filename,
                                    'type': a.type,
                                  },
                                )
                                .toList(),
                            'ai_structured': ?aiStructured,
                            if (blocksJson.isNotEmpty) 'blocks': blocksJson,
                          };

                          if (isEditing) {
                            await service.updateLesson(
                              id: existing.id,
                              title: title,
                              contentJson: contentJson,
                              minSubscriptionTier: selectedTier,
                              editedBy: _currentAdminId(),
                            );
                          } else {
                            if (createdLessonId == null) {
                              final lesson = await service.createLesson(
                                chapterId: chapterId,
                                title: title,
                                contentJson: contentJson,
                                displayOrder: nextDisplayOrder,
                                minSubscriptionTier: selectedTier,
                              );
                              createdLessonId = lesson?.id;
                            }

                            if (createdLessonId != null) {
                              await service.submitOrAutoApprove(
                                contentId: createdLessonId!,
                                contentType: 'lesson',
                                authorId: _currentAdminId(),
                                isSuperAdmin:
                                    ref
                                        .read(authProvider)
                                        .valueOrNull
                                        ?.isSuperAdmin ??
                                    false,
                              );
                            }
                          }

                          ref.invalidate(chaptersWithLessonsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.accentEmerald,
                                content: Text(
                                  isEditing
                                      ? 'Leçon "$title" mise à jour !'
                                      : 'Leçon "$title" créée et soumise pour validation !',
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing
                            ? 'Enregistrer les modifications'
                            : 'Enregistrer & Soumettre',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dérive `content_json['blocks']` (format natif, CF-001/CF-002) depuis la structuration IA brute.
  /// Mapping volontairement identique à `Lesson.blocks` dans
  /// `student_app/lib/core/models/student_models.dart` : mêmes types de blocs, même ordre, même
  /// formatage des puces — les deux applications n'ayant pas de package Dart partagé (voir
  /// `docs/CONTENT_FACTORY_GAP_ANALYSIS.md`), toute évolution de l'un doit être reportée manuellement
  /// sur l'autre tant qu'un package commun n'existe pas.
  List<Map<String, dynamic>>? _blocksFromAiStructured(
    Map<String, dynamic>? structured,
  ) {
    if (structured == null) return null;
    final blocks = <Map<String, dynamic>>[];
    var order = 0;

    final summary = structured['summary'] as String?;
    if (summary != null && summary.trim().isNotEmpty) {
      blocks.add({
        'type': 'paragraph',
        'body': summary.trim(),
        'order': order++,
      });
    }

    final sections = (structured['sections'] as List?) ?? const [];
    for (final s in sections) {
      if (s is Map) {
        final section = Map<String, dynamic>.from(s);
        final type = (section['type'] as String?)?.trim().toLowerCase();
        blocks.add({
          'type': (type != null && type.isNotEmpty) ? type : 'paragraph',
          'heading': section['heading'],
          'body': section['body'] ?? '',
          'formulas': _asStringList(section['latex_formulas']),
          'order': order++,
        });
      }
    }

    final traps = _asStringList(structured['common_traps']);
    if (traps.isNotEmpty) {
      blocks.add({
        'type': 'piege',
        'body': traps.map((t) => '•  $t').join('\n'),
        'order': order++,
      });
    }

    final tips = _asStringList(structured['exam_tips']);
    if (tips.isNotEmpty) {
      blocks.add({
        'type': 'conseil_examen',
        'body': tips.map((t) => '•  $t').join('\n'),
        'order': order++,
      });
    }

    return blocks.isEmpty ? null : blocks;
  }

  /// Résout la liste de blocs à utiliser pour l'aperçu/l'édition d'une leçon déjà enregistrée :
  /// `content_json['blocks']` natif en priorité (CF-002), sinon dérivé de `ai_structured` (leçons
  /// enregistrées avant l'éditeur de blocs manuel), sinon liste vide (repli sur `body` brut).
  List<Map<String, dynamic>> _resolveBlocksForPreview(
    Map<String, dynamic> contentJson,
  ) {
    final rawBlocks = contentJson['blocks'];
    if (rawBlocks is List && rawBlocks.isNotEmpty) {
      return rawBlocks
          .whereType<Map>()
          .map((b) => Map<String, dynamic>.from(b))
          .toList();
    }
    final structured = (contentJson['ai_structured'] as Map?)
        ?.cast<String, dynamic>();
    return _blocksFromAiStructured(structured) ?? const [];
  }

  /// Convertit une liste dynamique issue du JSON (`common_traps`, `exam_tips`, ...) en `List<String>`
  /// sûre, quelle que soit la forme exacte des éléments.
  List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  /// Carte d'édition d'un bloc dans l'éditeur de leçon (CF-002 partie 2) : type (dropdown), titre,
  /// contenu et formules, avec contrôles de réordonnancement/suppression.
  Widget _buildEditableBlockCard(
    _EditableBlock block, {
    required int index,
    required bool isFirst,
    required bool isLast,
    required VoidCallback onTypeChanged,
    required VoidCallback onMoveUp,
    required VoidCallback onMoveDown,
    required VoidCallback onDelete,
  }) {
    final meta = _previewSectionMeta(block.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: meta.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 15, color: meta.color),
              const SizedBox(width: 6),
              Text(
                'Bloc ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                tooltip: 'Monter',
                onPressed: isFirst ? null : onMoveUp,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                tooltip: 'Descendre',
                onPressed: isLast ? null : onMoveDown,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppTheme.accentRose,
                ),
                tooltip: 'Supprimer ce bloc',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ignore: deprecated_member_use
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: block.type,
            dropdownColor: AppTheme.primaryDark,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Type de bloc',
              isDense: true,
            ),
            items: kEditableBlockTypes
                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                .toList(),
            onChanged: (v) {
              block.type = v ?? 'paragraph';
              onTypeChanged();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: block.headingCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Titre du bloc (optionnel)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: block.bodyCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Contenu',
              alignLabelWithHint: true,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: block.formulasCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Formules LaTeX (une par ligne, optionnel)',
              alignLabelWithHint: true,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Même typologie que `BlockRendererRegistry` côté `student_app` (theoreme/definition/formule/
  /// methode/exemple) : icône + couleur par type, pour que cet aperçu reflète fidèlement ce que
  /// l'élève verra réellement, section par section — au lieu d'un rendu uniforme.
  ({IconData icon, Color color, String defaultLabel}) _previewSectionMeta(
    String? type,
  ) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'theoreme':
      case 'theorem':
        return (
          icon: Icons.verified_rounded,
          color: const Color(0xFF1E3A8A),
          defaultLabel: 'Théorème',
        );
      case 'definition':
        return (
          icon: Icons.menu_book_rounded,
          color: AppTheme.accentIndigo,
          defaultLabel: 'Définition',
        );
      case 'formule':
      case 'formula':
        return (
          icon: Icons.functions_rounded,
          color: AppTheme.accentEmerald,
          defaultLabel: 'Formule',
        );
      case 'methode':
      case 'method':
        return (
          icon: Icons.lightbulb_outline_rounded,
          color: AppTheme.accentAmber,
          defaultLabel: 'Méthode',
        );
      case 'exemple':
      case 'example':
        return (
          icon: Icons.auto_awesome_rounded,
          color: AppTheme.accentCyan,
          defaultLabel: 'Exemple',
        );
      case 'piege':
      case 'trap':
        return (
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFDC2626),
          defaultLabel: 'Piège classique',
        );
      case 'conseil_examen':
      case 'exam_tip':
        return (
          icon: Icons.tips_and_updates_rounded,
          color: const Color(0xFF059669),
          defaultLabel: 'Conseil d\'examen',
        );
      case 'paragraph':
        return (
          icon: Icons.notes_rounded,
          color: const Color(0xFF6B7280),
          defaultLabel: 'Paragraphe',
        );
      default:
        return (
          icon: Icons.article_rounded,
          color: const Color(0xFF6B7280),
          defaultLabel: 'Section',
        );
    }
  }

  /// Sépare un texte enregistré sous forme de puces (`•  item`, une par ligne — voir
  /// `_blocksFromAiStructured`) en éléments de liste. Fonctionne aussi sur du texte libre saisi à la
  /// main (une ligne = un élément), pour rester utile même sans puces explicites.
  List<String> _splitBulletBody(String body) {
    return body
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^•\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Dispatcheur générique par type de bloc — miroir de `BlockRendererRegistry.build` côté
  /// `student_app` : `paragraph` en texte simple, `piege`/`conseil_examen` en encart coloré à puces,
  /// tout le reste en carte titrée avec formules éventuelles.
  Widget _buildPreviewBlock(Map<String, dynamic> block) {
    final type =
        (block['type'] as String?)?.trim().toLowerCase() ?? 'paragraph';
    final body = (block['body'] as String?) ?? '';
    if (type == 'paragraph') {
      if (body.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF374151),
            height: 1.5,
          ),
        ),
      );
    }
    if (type == 'piege' || type == 'conseil_examen') {
      final meta = _previewSectionMeta(type);
      final items = _splitBulletBody(body);
      if (items.isEmpty) return const SizedBox.shrink();
      return _buildPreviewCallout(
        title: (block['heading'] as String?)?.trim().isNotEmpty == true
            ? (block['heading'] as String).trim()
            : meta.defaultLabel,
        icon: meta.icon,
        color: meta.color,
        bgColor: meta.color.withValues(alpha: 0.08),
        items: items,
      );
    }
    return _buildPreviewSection(block);
  }

  Widget _buildPreviewSection(Map<String, dynamic> section) {
    final meta = _previewSectionMeta(section['type'] as String?);
    final heading = (section['heading'] as String?)?.trim();
    final formulas = _asStringList(
      section['formulas'] ?? section['latex_formulas'],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 15, color: meta.color),
              const SizedBox(width: 6),
              Text(
                (heading != null && heading.isNotEmpty)
                    ? heading
                    : meta.defaultLabel,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: meta.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            section['body'] as String? ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
          for (final f in formulas)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  f,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCallout({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '•  $item',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLessonPreviewModal(
    BuildContext context, {
    required String title,
    required String tier,
    required String body,
    required List<Map<String, dynamic>> media,
    required List<Map<String, dynamic>> blocks,
    required String subjectName,
    required String chapterTitle,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 460,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5FA),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
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
                    const Icon(
                      Icons.smartphone_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aperçu — Application Élève',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
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
                          _studentBadge(subjectName, const Color(0xFF1E3A8A)),
                          _studentBadge(chapterTitle, const Color(0xFF7C3AED)),
                          _studentBadge(tier, const Color(0xFF0891B2)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (blocks.isNotEmpty)
                        // Rendu aligné sur BlockRendererRegistry (student_app/lib/core/rendering/) : un
                        // type de bloc = une couleur/icône, comme réellement vu par l'élève (CF-002 —
                        // avant ce correctif, cet aperçu ignorait pièges/conseils/formules et affichait
                        // toutes les sections de façon identique quel que soit leur type, ce qui rendait
                        // l'aperçu trompeur).
                        ...blocks.map(_buildPreviewBlock)
                      else
                        Text(
                          body.isEmpty
                              ? 'Aucun contenu rédigé pour le moment.'
                              : body,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF374151),
                            height: 1.5,
                          ),
                        ),
                      if (media.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: media
                              .map(
                                (m) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.attach_file_rounded,
                                        size: 14,
                                        color: Color(0xFF4B5563),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (m['filename'] ?? m['url'] ?? '')
                                            .toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Aperçu illustratif — le rendu réel dans l\'application élève pourra différer légèrement.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLessonVersionHistoryModal(BuildContext context, Lesson lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.history_rounded,
          iconColor: AppTheme.accentCyan,
          text: 'Historique : ${lesson.title}',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 520,
          height: 420,
          child: Consumer(
            builder: (context, ref, _) {
              final versionsAsync = ref.watch(
                lessonVersionsProvider(lesson.id),
              );
              return versionsAsync.when(
                data: (versions) {
                  if (versions.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucune version antérieure enregistrée — cette leçon n\'a jamais été modifiée depuis sa création.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final v = versions[idx];
                      final body = v.contentJson['body'] as String? ?? '';
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
                                Text(
                                  'Version ${v.versionNumber}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  v.publishedAt
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        backgroundColor:
                                            AppTheme.primarySurface,
                                        title: AppDialogTitle(
                                          icon: Icons.restore_rounded,
                                          text: 'Restaurer cette version ?',
                                          onClose: () =>
                                              Navigator.pop(c, false),
                                        ),
                                        content: Text(
                                          'Le contenu actuel de la leçon sera remplacé par celui de la version ${v.versionNumber}.',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Annuler'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Restaurer'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    if (!context.mounted) return;
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final navigator = Navigator.of(context);
                                    try {
                                      final service = ref.read(
                                        supabaseServiceProvider,
                                      );
                                      await service.updateLesson(
                                        id: lesson.id,
                                        contentJson: v.contentJson,
                                        editedBy: _currentAdminId(),
                                      );
                                      ref.invalidate(
                                        chaptersWithLessonsProvider,
                                      );
                                      ref.invalidate(
                                        lessonVersionsProvider(lesson.id),
                                      );
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              AppTheme.accentEmerald,
                                          content: Text(
                                            'Version ${v.versionNumber} restaurée.',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.accentRose,
                                          content: Text(
                                            'Erreur lors de la restauration : $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Restaurer',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.accentEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              body.isEmpty ? '(contenu vide)' : body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
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
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fermer',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'erreur réutilisable (messages d'exception Postgrest potentiellement longs, affichés à
/// part plutôt que dans un TextField.errorText).
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
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.accentRose,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.accentRose,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
