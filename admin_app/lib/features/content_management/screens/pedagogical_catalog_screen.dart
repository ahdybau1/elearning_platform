import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class PedagogicalCatalogScreen extends ConsumerStatefulWidget {
  const PedagogicalCatalogScreen({super.key});

  @override
  ConsumerState<PedagogicalCatalogScreen> createState() =>
      _PedagogicalCatalogScreenState();
}

class _PedagogicalCatalogScreenState
    extends ConsumerState<PedagogicalCatalogScreen> {
  String? _selectedSubjectId;
  bool _showInactiveSubjects = false;
  bool _isImportingSuggestions = false;

  final List<Map<String, dynamic>> _defaultCatalog = [
    {
      'subject': 'Mathématiques',
      'types': [
        {
          'name': 'Définition',
          'desc': 'Notion fondamentale avec notations rigoureuses',
        },
        {
          'name': 'Théorème',
          'desc': 'Énoncé mathématique majeur avec démonstration type',
        },
        {
          'name': 'Propriété / Corollaire',
          'desc': 'Conséquence directe d\'un théorème',
        },
        {
          'name': 'Formule & Identité',
          'desc': 'Expression algébrique ou trigonométrique essentielle',
        },
        {
          'name': 'Méthode / Savoir-Faire',
          'desc': 'Guide pas-à-pas pour résoudre un problème type',
        },
        {
          'name': 'Piège & Erreur Classique',
          'desc': 'Mise en garde contre les confusions fréquentes',
        },
      ],
    },
    {
      'subject': 'Physique - Chimie',
      'types': [
        {
          'name': 'Loi Physique',
          'desc': 'Lois de Newton, thermodynamique, électromagnétisme...',
        },
        {
          'name': 'Formule & Unités SI',
          'desc': 'Grandeurs physiques avec unités normalisées',
        },
        {
          'name': 'Protocole Expérimental',
          'desc': 'Schéma de montage et étapes de laboratoire',
        },
        {
          'name': 'Équation-Bilan & Réaction',
          'desc': 'Équilibrage stœchiométrique et états de la matière',
        },
        {
          'name': 'Interprétation Microscopique',
          'desc': 'Explication au niveau atomique ou moléculaire',
        },
      ],
    },
    {
      'subject': 'Français & Littérature',
      'types': [
        {
          'name': 'Règle de Grammaire',
          'desc': 'Accords, syntaxe et conjugaison avancée',
        },
        {
          'name': 'Figure de Style',
          'desc': 'Métaphore, allégorie, oxymore avec exemples',
        },
        {
          'name': 'Texte Support / Extrait',
          'desc': 'Passage littéraire pour commentaire composé',
        },
        {
          'name': 'Plan Dialectique',
          'desc': 'Structure de dissertation (Thèse, Antithèse, Synthèse)',
        },
        {
          'name': 'Fiche Auteur & Mouvement',
          'desc': 'Contexte historique et biographie littéraire',
        },
      ],
    },
    {
      'subject': 'Sciences de la Vie et de la Terre',
      'types': [
        {
          'name': 'Schéma Fonctionnel',
          'desc': 'Diagramme anatomique ou géologique légendé',
        },
        {
          'name': 'Mécanisme Biologique',
          'desc': 'Cycle cellulaire, génétique, photosynthèse...',
        },
        {
          'name': 'Vocabulaire Clé',
          'desc': 'Terminologie scientifique spécialisée',
        },
        {
          'name': 'Démarche d\'Investigation',
          'desc': 'Hypothèse, expérience, observation, conclusion',
        },
      ],
    },
  ];

  /// Types suggérés pour une matière donnée (par nom), s'il y en a — sert uniquement de point de
  /// départ pour un import réel en base via "Importer les types suggérés" ; jamais affiché comme
  /// si c'était déjà injecté dans le prompt IA tant que ce n'est pas réellement enregistré.
  List<Map<String, String>>? _suggestionsFor(String subjectName) {
    for (final entry in _defaultCatalog) {
      if ((entry['subject'] as String).toLowerCase() ==
          subjectName.toLowerCase()) {
        return (entry['types'] as List).cast<Map<String, String>>();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(
      subjectsProvider((
        countryId: null,
        includeInactive: _showInactiveSubjects,
      )),
    );
    final subjects = subjectsAsync.valueOrNull ?? [];
    if (subjects.isNotEmpty && _selectedSubjectId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSubjectId == null) {
          setState(() => _selectedSubjectId = subjects.first.id);
        }
      });
    }
    final selectedSubjectName = subjects
        .where((s) => s.id == _selectedSubjectId)
        .map((s) => s.name)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — Column plutôt que Row : un Wrap de PLUSIEURS boutons placé comme simple frère
            // d'un Expanded ne rétrécit jamais (largeur "tout sur une ligne" calculée en espace
            // illimité avant que le Row ne distribue quoi que ce soit) — avec 3 boutons ici, ça
            // affamait le titre jusqu'à l'écraser lettre par lettre sur mobile, même protégé par
            // Expanded (même bug que academic_tree_screen.dart, retour utilisateur réel très
            // insistant, 2026-08-30). Titre/icône en haut sur toute la largeur, boutons dans leur
            // propre Wrap en dessous.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: AppTheme.accentEmerald,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catalogue Pédagogique',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Structure type des cours et typologie d\'éléments pour l\'Assistant IA',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCreateOrEditSubjectModal(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nouvelle Matière'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectedSubjectId == null
                          ? null
                          : () => _showAiCatalogGenerationModal(context),
                      icon: const Icon(Icons.psychology_rounded, size: 18),
                      label: const Text('Générer par IA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectedSubjectId == null
                          ? null
                          : () => _showAddTypeDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter un Type d\'Élément'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subject Selector Bar
            subjectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text(
                'Erreur: $err',
                style: const TextStyle(color: Colors.red),
              ),
              data: (_) => subjects.isEmpty
                  ? Text(
                      'Aucune matière créée. Cliquez sur "Nouvelle Matière" pour commencer.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    )
                  // Wrap plutôt qu'un Row+SingleChildScrollView horizontal : les puces passaient à
                  // la ligne à l'infini sans aucun indice visuel de défilement — techniquement
                  // scrollable mais imperceptible, surtout à mesure que le nombre de matières
                  // grandit. Un Wrap les fait simplement retourner à la ligne, tout reste visible.
                  : Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: subjects.map((s) {
                        final isSelected = s.id == _selectedSubjectId;
                        return ChoiceChip(
                          label: Text(
                            s.isActive ? s.name : '${s.name} (archivée)',
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedSubjectId = s.id);
                            }
                          },
                          selectedColor: AppTheme.accentEmerald.withValues(
                            alpha: 0.2,
                          ),
                          backgroundColor: s.isActive
                              ? AppTheme.cardBackground
                              : AppTheme.accentAmber.withValues(alpha: 0.08),
                          labelStyle: GoogleFonts.inter(
                            color: !s.isActive
                                ? AppTheme.accentAmber
                                : (isSelected
                                      ? AppTheme.accentEmerald
                                      : AppTheme.textSecondary),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.accentEmerald
                                  : AppTheme.borderColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),
            // Wrap plutôt que Row : jusqu'à 4 boutons (Modifier/Archiver/Supprimer) après le
            // switch débordaient hors de l'écran sur mobile, "Modifier la matière" coupé (retour
            // utilisateur réel, captures d'écran, 2026-08-31).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 8,
              children: [
                Switch(
                  value: _showInactiveSubjects,
                  activeThumbColor: AppTheme.accentAmber,
                  onChanged: (v) => setState(() => _showInactiveSubjects = v),
                ),
                Text(
                  'Afficher les matières archivées',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (_selectedSubjectId != null) ...[
                  const SizedBox(width: 20),
                  TextButton.icon(
                    onPressed: () {
                      final subject = subjects
                          .where((s) => s.id == _selectedSubjectId)
                          .firstOrNull;
                      if (subject != null)
                        _showCreateOrEditSubjectModal(
                          context,
                          existing: subject,
                        );
                    },
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: AppTheme.accentBlue,
                    ),
                    label: Text(
                      'Modifier la matière',
                      style: GoogleFonts.inter(
                        color: AppTheme.accentBlue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final subject = subjects
                          .where((s) => s.id == _selectedSubjectId)
                          .firstOrNull;
                      if (subject == null) return;
                      subject.isActive
                          ? _showDeactivateSubjectConfirmation(context, subject)
                          : _showReactivateSubjectConfirmation(
                              context,
                              subject,
                            );
                    },
                    icon: Icon(
                      subjects
                                  .where((s) => s.id == _selectedSubjectId)
                                  .firstOrNull
                                  ?.isActive ??
                              true
                          ? Icons.archive_rounded
                          : Icons.unarchive_rounded,
                      size: 14,
                      color: AppTheme.accentAmber,
                    ),
                    label: Text(
                      subjects
                                  .where((s) => s.id == _selectedSubjectId)
                                  .firstOrNull
                                  ?.isActive ??
                              true
                          ? 'Archiver la matière'
                          : 'Désarchiver la matière',
                      style: GoogleFonts.inter(
                        color: AppTheme.accentAmber,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (!(subjects
                          .where((s) => s.id == _selectedSubjectId)
                          .firstOrNull
                          ?.isActive ??
                      true))
                    TextButton.icon(
                      onPressed: () {
                        final subject = subjects
                            .where((s) => s.id == _selectedSubjectId)
                            .firstOrNull;
                        if (subject != null)
                          _showPermanentDeleteSubjectConfirmation(
                            context,
                            subject,
                          );
                      },
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        size: 14,
                        color: AppTheme.accentRose,
                      ),
                      label: Text(
                        'Supprimer définitivement',
                        style: GoogleFonts.inter(
                          color: AppTheme.accentRose,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Content Grid
            Expanded(
              child: _selectedSubjectId == null
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer(
                      builder: (context, ref, _) {
                        final catalogAsync = ref.watch(
                          contentCatalogProvider(_selectedSubjectId!),
                        );

                        return catalogAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(
                            child: Text(
                              'Erreur: $err',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          data: (items) {
                            if (items.isEmpty) {
                              final suggestions = selectedSubjectName == null
                                  ? null
                                  : _suggestionsFor(selectedSubjectName);
                              return _buildEmptyState(suggestions);
                            }
                            // crossAxisCount fixé à 3 sans seuil mobile : chaque carte n'avait
                            // plus que ~110px de large sur téléphone, le badge "Injecté dans
                            // Prompt IA" débordait sans retour à la ligne (retour utilisateur
                            // réel, 2026-08-30). Même logique responsive que la grille KPI du
                            // tableau de bord (dashboard_overview_screen.dart).
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount =
                                    constraints.maxWidth > 900
                                    ? 3
                                    : (constraints.maxWidth > 550 ? 2 : 1);
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        // 2.4 restait trop court en 1 colonne : le contenu réel
                                        // (icône+titre, 3 lignes de description, badge "Injecté
                                        // dans Prompt IA") dépassait la hauteur de la carte et
                                        // débordait visuellement sur la carte suivante (retour
                                        // utilisateur réel, captures d'écran, 2026-08-30).
                                        childAspectRatio: crossAxisCount == 1
                                            ? 1.3
                                            : 1.6,
                                      ),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) =>
                                      _buildCatalogCard(items[index]),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide honnête : aucune fausse donnée affichée comme si elle était déjà en base. Si des
  /// types standards existent pour cette matière, propose de les importer réellement (insert en
  /// base) plutôt que de les afficher localement avec un badge "Injecté dans Prompt IA" mensonger.
  Widget _buildEmptyState(List<Map<String, String>>? suggestions) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun type d\'élément défini pour cette matière.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tant qu\'aucun type n\'est enregistré, l\'IA utilise une structure générique par défaut.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (suggestions != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isImportingSuggestions
                  ? null
                  : () => _importSuggestions(suggestions),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
              ),
              icon: _isImportingSuggestions
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _isImportingSuggestions
                    ? 'Import en cours...'
                    : 'Importer les ${suggestions.length} types standards suggérés',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _importSuggestions(List<Map<String, String>> suggestions) async {
    if (_selectedSubjectId == null || _isImportingSuggestions) return;
    setState(() => _isImportingSuggestions = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      for (final s in suggestions) {
        await service.createContentCatalogItem(
          subjectId: _selectedSubjectId!,
          elementType: s['name'] ?? '',
          description: s['desc'],
        );
      }
      ref.invalidate(contentCatalogProvider(_selectedSubjectId!));
    } finally {
      if (mounted) setState(() => _isImportingSuggestions = false);
    }
  }

  Future<void> _confirmDeleteCatalogItem(ContentCatalogItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: AppDialogTitle(
          icon: Icons.delete_forever_rounded,
          iconColor: AppTheme.accentRose,
          text: 'Supprimer "${item.elementType}" ?',
          onClose: () => Navigator.pop(ctx, false),
        ),
        content: Text(
          'Ce type d\'élément ne sera plus proposé à l\'IA pour cette matière.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final service = ref.read(supabaseServiceProvider);
    await service.deleteContentCatalogItem(item.id);
    ref.invalidate(contentCatalogProvider(item.subjectId));
  }

  Widget _buildCatalogCard(ContentCatalogItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: AppTheme.accentPurple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.elementType,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                color: AppTheme.cardBackground,
                onSelected: (val) {
                  if (val == 'edit') {
                    _showAddTypeDialog(context, existing: item);
                  } else if (val == 'delete') {
                    _confirmDeleteCatalogItem(item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      'Modifier',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              item.description ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: AppTheme.accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Injecté dans Prompt IA',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _currentAdminId() {
    return ref.read(authProvider).valueOrNull?.id ??
        '00000000-0000-0000-0000-000000000001';
  }

  /// Dialogue de confirmation générique pour archiver/désarchiver/supprimer définitivement une
  /// matière — même pattern que celui des autres écrans de contenu (Leçons, Exercices).
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
          backgroundColor: AppTheme.cardBackground,
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
                        ref.invalidate(subjectsProvider);
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

  void _showDeactivateSubjectConfirmation(
    BuildContext context,
    Subject subject,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.archive_rounded,
      iconColor: AppTheme.accentAmber,
      title: 'Archiver "${subject.name}" ?',
      content: Text(
        'Cette matière sera masquée par défaut (visible via "Afficher les matières archivées"), '
        'pas supprimée — vous pourrez la désarchiver ou la supprimer définitivement plus tard.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      confirmLabel: 'Archiver',
      confirmColor: AppTheme.accentAmber,
      onConfirm: () async {
        await service.toggleSubjectActive(subject.id, false);
        if (subject.id == _selectedSubjectId) {
          setState(() => _selectedSubjectId = null);
        }
      },
      successMessage: 'Matière "${subject.name}" archivée.',
    );
  }

  void _showReactivateSubjectConfirmation(
    BuildContext context,
    Subject subject,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.unarchive_rounded,
      iconColor: AppTheme.accentEmerald,
      title: 'Désarchiver "${subject.name}" ?',
      content: Text(
        'Cette matière redeviendra active et visible dans l\'application.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      confirmLabel: 'Désarchiver',
      confirmColor: AppTheme.accentEmerald,
      onConfirm: () => service.toggleSubjectActive(subject.id, true),
      successMessage: 'Matière "${subject.name}" désarchivée.',
    );
  }

  void _showPermanentDeleteSubjectConfirmation(
    BuildContext context,
    Subject subject,
  ) {
    final service = ref.read(supabaseServiceProvider);
    _showConfirmActionDialog(
      context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppTheme.accentRose,
      title: 'Supprimer définitivement "${subject.name}" ?',
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
        ),
        child: Text(
          'IRRÉVERSIBLE : refusé automatiquement s\'il reste des chapitres rattachés à cette '
          'matière (dans n\'importe quelle classe) — supprimez-les d\'abord depuis Leçons & Cours.',
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
          service.permanentlyDeleteSubject(subject.id, _currentAdminId()),
      successMessage: 'Matière "${subject.name}" supprimée définitivement.',
      typedConfirmationTarget: subject.name,
    );
  }

  /// Création ou édition d'une matière, avec rattachement à une ou plusieurs Classes/Séries —
  /// sans ce rattachement la matière resterait invisible dans le sélecteur "Matière" de
  /// Chapitres & Leçons (voir linkSubjectToClasses).
  void _showCreateOrEditSubjectModal(
    BuildContext context, {
    Subject? existing,
  }) {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    String? selectedCountryId = existing?.countryId;
    Set<String> selectedClassIds = {};
    Set<String> initialClassIds = {};
    // Classes/séries liées AU MOMENT DE L'OUVERTURE du formulaire, y compris celles depuis
    // archivées dans l'Arbre Académique (nodesByTypeProvider les exclut) — sans ça, un lien
    // devenu invisible ne pourrait jamais être vu ni retiré ; il resterait rattaché pour toujours.
    List<AcademicNode> initialLinkedNodes = [];
    bool linksInitialized = !isEditing;
    Future<List<AcademicNode>>? linksFuture;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: AppDialogTitle(
              icon: Icons.auto_stories_rounded,
              text: isEditing ? 'Modifier la Matière' : 'Nouvelle Matière',
              onClose: () => Navigator.pop(ctx),
            ),
            content: SizedBox(
              width: 480,
              height: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nom (ex: Mathématiques)',
                        prefixIcon: Icon(Icons.auto_stories_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Code (ex: MATH)',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, _) {
                        final countriesAsync = ref.watch(
                          nodesByTypeProvider('country'),
                        );
                        final countries = countriesAsync.valueOrNull ?? [];
                        // Si le pays actuellement rattaché a depuis été archivé dans l'Arbre
                        // Académique, il n'apparaît plus dans `countries` (filtré is_active) —
                        // sans ce garde-fou, DropdownButtonFormField plante (aucun item ne
                        // correspond à la valeur sélectionnée).
                        final safeSelectedCountryId =
                            countries.any((c) => c.id == selectedCountryId)
                            ? selectedCountryId
                            : null;
                        return DropdownButtonFormField<String?>(
                          // ignore: deprecated_member_use
                          value: safeSelectedCountryId,
                          dropdownColor: AppTheme.primaryDark,
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Pays (optionnel)',
                            prefixIcon: Icon(Icons.public_rounded, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Non spécifié'),
                            ),
                            ...countries.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() => selectedCountryId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Classes / Séries où cette matière est enseignée',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Obligatoire pour que la matière apparaisse dans le sélecteur de Chapitres & Leçons.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isEditing && !linksInitialized)
                      Builder(
                        builder: (context) {
                          linksFuture ??= ref
                              .read(supabaseServiceProvider)
                              .fetchClassesForSubject(existing.id);
                          return FutureBuilder<List<AcademicNode>>(
                            future: linksFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: LinearProgressIndicator(),
                                );
                              }
                              // Ne s'exécute qu'une fois : bascule sur la liste interactive dès que
                              // les liens actuels sont connus, sans effacer une sélection en cours.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!linksInitialized) {
                                  initialLinkedNodes = snapshot.data ?? [];
                                  initialClassIds = initialLinkedNodes
                                      .map((n) => n.id)
                                      .toSet();
                                  setModalState(() {
                                    selectedClassIds = Set.from(
                                      initialClassIds,
                                    );
                                    linksInitialized = true;
                                  });
                                }
                              });
                              return const SizedBox.shrink();
                            },
                          );
                        },
                      )
                    else
                      Consumer(
                        builder: (context, ref, _) {
                          final classesAsync = ref.watch(
                            nodesByTypeProvider('class'),
                          );
                          final seriesAsync = ref.watch(
                            nodesByTypeProvider('series'),
                          );
                          final options = <AcademicNode>[
                            ...classesAsync.valueOrNull ?? [],
                            ...seriesAsync.valueOrNull ?? [],
                          ]..sort((a, b) => a.name.compareTo(b.name));
                          // Une classe/série liée à cette matière peut avoir été archivée depuis
                          // l'Arbre Académique entre-temps : elle n'apparaît plus dans `options`
                          // (filtré is_active) mais reste dans selectedClassIds tant qu'on ne
                          // l'affiche pas ici — sinon impossible à voir ni à détacher.
                          final archivedButLinked = initialLinkedNodes
                              .where((n) => !options.any((o) => o.id == n.id))
                              .toList();
                          if (options.isEmpty && archivedButLinked.isEmpty) {
                            return Text(
                              'Aucune classe/série configurée.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentRose,
                              ),
                            );
                          }
                          return Column(
                            children: [
                              ...options.map(
                                (c) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: selectedClassIds.contains(c.id),
                                  activeColor: AppTheme.accentEmerald,
                                  title: Text(
                                    c.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onChanged: (checked) => setModalState(() {
                                    if (checked == true) {
                                      selectedClassIds.add(c.id);
                                    } else {
                                      selectedClassIds.remove(c.id);
                                    }
                                  }),
                                ),
                              ),
                              ...archivedButLinked.map(
                                (c) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: selectedClassIds.contains(c.id),
                                  activeColor: AppTheme.accentAmber,
                                  title: Text(
                                    '${c.name} (archivée)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppTheme.accentAmber,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Décochez pour retirer ce lien devenu obsolète',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  onChanged: (checked) => setModalState(() {
                                    if (checked == true) {
                                      selectedClassIds.add(c.id);
                                    } else {
                                      selectedClassIds.remove(c.id);
                                    }
                                  }),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    if (submitError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRose.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          submitError!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.accentRose,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final code = codeController.text.trim();
                        if (name.isEmpty || code.isEmpty) {
                          setModalState(
                            () => submitError =
                                'Le nom et le code sont obligatoires.',
                          );
                          return;
                        }
                        setModalState(() {
                          submitError = null;
                          isLoading = true;
                        });
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          String subjectId;
                          if (isEditing) {
                            await service.updateSubject(
                              id: existing.id,
                              name: name,
                              code: code,
                              updateCountryId: true,
                              countryId: selectedCountryId,
                            );
                            subjectId = existing.id;
                            final toAdd = selectedClassIds.difference(
                              initialClassIds,
                            );
                            final toRemove = initialClassIds.difference(
                              selectedClassIds,
                            );
                            for (final id in toAdd) {
                              await service.linkSubjectToClass(subjectId, id);
                            }
                            for (final id in toRemove) {
                              await service.unlinkSubjectFromClass(
                                subjectId,
                                id,
                              );
                            }
                          } else {
                            final created = await service.createSubject(
                              name: name,
                              code: code,
                              countryId: selectedCountryId,
                            );
                            if (created == null)
                              throw Exception('La création a échoué.');
                            subjectId = created.id;
                            await service.linkSubjectToClasses(
                              subjectId,
                              selectedClassIds.toList(),
                            );
                          }
                          ref.invalidate(subjectsProvider);
                          ref.invalidate(subjectsForClassProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            setState(() => _selectedSubjectId = subjectId);
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
                            : 'Créer la matière',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Génération IA des types d'éléments du catalogue pédagogique pour la matière sélectionnée —
  /// même flux en 2 phases que la génération d'exercices (paramètres → suggestions à cocher →
  /// import réel), pour ne pas avoir à taper chaque type à la main.
  void _showAiCatalogGenerationModal(BuildContext context) {
    if (_selectedSubjectId == null) return;
    final countController = TextEditingController(text: '8');
    final levelController = TextEditingController();
    final notesController = TextEditingController();
    String? submitError;
    bool isGenerating = false;
    List<Map<String, dynamic>>? generated;
    Set<int> selectedIndices = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.psychology_rounded,
            iconColor: AppTheme.accentCyan,
            text: 'Génération IA — Types d\'Éléments',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (generated == null) ...[
                    TextField(
                      controller: levelController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Niveau scolaire (optionnel, ex: Terminale)',
                        prefixIcon: Icon(Icons.school_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de types à générer (1-20)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Notes / directives (optionnel)',
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${generated!.length} type(s) généré(s) — décochez ceux à ignorer, puis importez la sélection.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(generated!.length, (i) {
                      final item = generated![i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
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
                          title: Text(
                            item['element_type'] as String? ?? '',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            item['description'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  if (submitError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        submitError!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.accentRose,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isGenerating ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            if (generated == null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                ),
                onPressed: isGenerating
                    ? null
                    : () async {
                        final count =
                            int.tryParse(countController.text.trim()) ?? 8;
                        setModalState(() {
                          isGenerating = true;
                          submitError = null;
                        });
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          final subject = await service.getSubject(
                            _selectedSubjectId!,
                          );
                          final result = await service.generateAiCatalogTypes(
                            subjectId: _selectedSubjectId,
                            subjectName: subject?.name ?? '',
                            countryId: subject?.countryId,
                            educationLevel: levelController.text.trim().isEmpty
                                ? null
                                : levelController.text.trim(),
                            count: count,
                            rawNotes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );
                          setModalState(() {
                            isGenerating = false;
                            generated = result;
                            selectedIndices = Set.from(
                              List.generate(result.length, (i) => i),
                            );
                          });
                        } catch (e) {
                          setModalState(() {
                            isGenerating = false;
                            submitError = '$e';
                          });
                        }
                      },
                icon: isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  isGenerating ? 'Génération en cours...' : 'Générer',
                ),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                ),
                onPressed: isGenerating || selectedIndices.isEmpty
                    ? null
                    : () async {
                        setModalState(() => isGenerating = true);
                        try {
                          final service = ref.read(supabaseServiceProvider);
                          // Évite les doublons si "Générer par IA" a déjà été lancé une première
                          // fois pour cette matière (suggestions qui se recoupent) : on ignore
                          // silencieusement tout type dont le nom existe déjà dans le catalogue.
                          final existing = await ref.read(
                            contentCatalogProvider(_selectedSubjectId!).future,
                          );
                          final existingNames = existing
                              .map((e) => e.elementType.toLowerCase().trim())
                              .toSet();
                          var skipped = 0;
                          for (final i in selectedIndices) {
                            final item = generated![i];
                            final name = (item['element_type'] as String? ?? '')
                                .trim();
                            if (existingNames.contains(name.toLowerCase())) {
                              skipped++;
                              continue;
                            }
                            await service.createContentCatalogItem(
                              subjectId: _selectedSubjectId!,
                              elementType: name,
                              description: item['description'] as String?,
                            );
                            existingNames.add(name.toLowerCase());
                          }
                          ref.invalidate(
                            contentCatalogProvider(_selectedSubjectId!),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (skipped > 0 && context.mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.accentAmber,
                                content: Text(
                                  '$skipped type(s) déjà existant(s) ignoré(s).',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isGenerating = false;
                            submitError = '$e';
                          });
                        }
                      },
                icon: isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text('Importer ${selectedIndices.length} type(s)'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddTypeDialog(
    BuildContext context, {
    ContentCatalogItem? existing,
  }) {
    final isEditing = existing != null;
    final typeCtrl = TextEditingController(text: existing?.elementType ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: AppDialogTitle(
          icon: Icons.bookmark_outline_rounded,
          iconColor: AppTheme.accentPurple,
          text: isEditing
              ? 'Modifier le type d\'élément'
              : 'Ajouter un type d\'élément',
          onClose: () => Navigator.pop(ctx),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText:
                      'Nom du type (ex: Théorème, Définition, Schéma...)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description & Directives pédagogiques pour l\'IA',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
            ),
            onPressed: () async {
              if (typeCtrl.text.trim().isEmpty || _selectedSubjectId == null)
                return;
              final service = ref.read(supabaseServiceProvider);
              if (isEditing) {
                await service.updateContentCatalogItem(
                  existing.id,
                  elementType: typeCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
              } else {
                await service.createContentCatalogItem(
                  subjectId: _selectedSubjectId!,
                  elementType: typeCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
              }
              ref.invalidate(contentCatalogProvider(_selectedSubjectId!));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              isEditing ? 'Enregistrer les modifications' : 'Enregistrer',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
