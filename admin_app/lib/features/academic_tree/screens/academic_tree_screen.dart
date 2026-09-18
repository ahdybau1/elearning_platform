import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';
import 'subjects_by_class_screen.dart';

/// Écran de gestion de l'Arbre Académique — Refonte ergonomique pleine largeur par exploration
/// de niveaux (Level-by-Level Exploration).
///
/// L'ancien système à double colonne (arbre étroit à gauche + détails écrasés à droite) est
/// complètement remplacé : chaque niveau (Pays, Section, Enseignement, Classe, Série) s'affiche
/// désormais dans une vue dédiée spacieuse occupant 100% de la largeur et de la hauteur utiles.
/// La navigation s'effectue par fil d'Ariane interactif et bouton retour, avec conservation de
/// l'ensemble des opérations métiers (création, édition, duplication, archivage, réactivation,
/// suppression définitive, fusion et jumelage).
class AcademicTreeScreen extends ConsumerStatefulWidget {
  const AcademicTreeScreen({super.key});

  @override
  ConsumerState<AcademicTreeScreen> createState() => _AcademicTreeScreenState();
}

class _AcademicTreeScreenState extends ConsumerState<AcademicTreeScreen>
    with WidgetsBindingObserver {
  /// Pile ordonnée des identifiants de nœuds représentant le chemin actuellement affiché.
  /// Liste vide = niveau racine (accueil des Pays).
  List<String> _pathNodeIds = [];

  /// Historique des chemins précédents (pile de retour en arrière).
  final List<List<String>> _historyPast = [];

  /// Historique des chemins suivants (pile d'avance vers l'avant après un retour).
  final List<List<String>> _historyFuture = [];

  bool get _canGoBack => _historyPast.isNotEmpty || _pathNodeIds.isNotEmpty;
  bool get _canGoForward => _historyFuture.isNotEmpty;

  bool _showInactive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Filtre local à l'intérieur de la liste des enfants d'un nœud.
  String _childSearchQuery = '';
  final TextEditingController _childSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _childSearchController.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (_canGoBack) {
      _goBack();
      return true;
    }
    return false;
  }

  String _currentAdminId() {
    return ref.read(authProvider).valueOrNull?.id ??
        '00000000-0000-0000-0000-000000000001';
  }

  /// Reconstruit la carte id → nœud à partir de l'arbre chargé.
  Map<String, AcademicNode> _flattenById(List<AcademicNode> roots) {
    final map = <String, AcademicNode>{};
    void walk(AcademicNode n) {
      map[n.id] = n;
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final r in roots) {
      walk(r);
    }
    return map;
  }

  /// Liste des ancêtres d'un nœud dans l'ordre racine -> parent.
  List<AcademicNode> _getAncestors(
    String nodeId,
    Map<String, AcademicNode> byId,
  ) {
    final ancestors = <AcademicNode>[];
    var current = byId[nodeId];
    while (current != null &&
        current.parentId != null &&
        byId.containsKey(current.parentId)) {
      final parent = byId[current.parentId]!;
      ancestors.insert(0, parent);
      current = parent;
    }
    return ancestors;
  }

  String _nodePath(AcademicNode node, Map<String, AcademicNode> byId) {
    final parts = <String>[node.name];
    var current = node;
    while (current.parentId != null && byId.containsKey(current.parentId)) {
      current = byId[current.parentId]!;
      parts.add(current.name);
    }
    return parts.reversed.join(' › ');
  }

  int _countDescendants(AcademicNode node) {
    var count = 0;
    for (final child in node.children) {
      count += 1 + _countDescendants(child);
    }
    return count;
  }

  /// Récupère le nombre d'élèves pour un nœud de manière sécurisée (sans crash si le service est indisponible).
  Future<int> _countProfiles(String nodeId) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      return await service.countProfilesForNode(nodeId);
    } catch (_) {
      return 0;
    }
  }

  /// Recherche récursive sur tous les nœuds de l'arbre pour les résultats de recherche globale.
  List<AcademicNode> _searchAllNodes(
    List<AcademicNode> roots,
    String query,
  ) {
    final results = <AcademicNode>[];
    if (query.isEmpty) return results;
    final q = query.toLowerCase();

    void walk(AcademicNode n) {
      final matchesName = n.name.toLowerCase().contains(q);
      final matchesCode = n.code != null && n.code!.toLowerCase().contains(q);
      if (matchesName || matchesCode) {
        results.add(n);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final r in roots) {
      walk(r);
    }
    return results;
  }

  bool _pathEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Nettoie la pile de chemin si certains nœuds n'existent plus suite à une suppression ou
  /// un rechargement sans archived.
  void _sanitizePath(Map<String, AcademicNode> byId) {
    final validPath = <String>[];
    for (final id in _pathNodeIds) {
      if (byId.containsKey(id)) {
        validPath.add(id);
      } else {
        break;
      }
    }
    if (validPath.length != _pathNodeIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pathNodeIds = validPath;
            _historyPast.removeWhere((p) => p.any((id) => !byId.containsKey(id)));
            _historyFuture.removeWhere((p) => p.any((id) => !byId.containsKey(id)));
          });
        }
      });
    }
  }

  /// Navigue vers un nouveau chemin en enregistrant l'état dans l'historique de retour.
  void _navigateToPath(List<String> newPath, {bool clearFuture = true}) {
    if (_pathEquals(_pathNodeIds, newPath)) return;
    setState(() {
      _historyPast.add(List<String>.from(_pathNodeIds));
      _pathNodeIds = List<String>.from(newPath);
      if (clearFuture) {
        _historyFuture.clear();
      }
      _searchController.clear();
      _searchQuery = '';
      _childSearchController.clear();
      _childSearchQuery = '';
    });
  }

  /// Recule d'un écran dans l'historique de navigation ("Retour en arrière").
  void _goBack() {
    if (_historyPast.isNotEmpty) {
      setState(() {
        _historyFuture.add(List<String>.from(_pathNodeIds));
        _pathNodeIds = _historyPast.removeLast();
        _searchController.clear();
        _searchQuery = '';
        _childSearchController.clear();
        _childSearchQuery = '';
      });
    } else if (_pathNodeIds.isNotEmpty) {
      setState(() {
        _historyFuture.add(List<String>.from(_pathNodeIds));
        _pathNodeIds = _pathNodeIds.sublist(0, _pathNodeIds.length - 1);
        _searchController.clear();
        _searchQuery = '';
        _childSearchController.clear();
        _childSearchQuery = '';
      });
    }
  }

  /// Avance d'un écran dans l'historique après avoir reculé ("Aller en avant").
  void _goForward() {
    if (_historyFuture.isNotEmpty) {
      setState(() {
        _historyPast.add(List<String>.from(_pathNodeIds));
        _pathNodeIds = _historyFuture.removeLast();
        _searchController.clear();
        _searchQuery = '';
        _childSearchController.clear();
        _childSearchQuery = '';
      });
    }
  }

  /// Revient directement à l'accueil / racine de l'arbre académique (les Pays).
  void _goToRoot() {
    if (_pathNodeIds.isNotEmpty) {
      _navigateToPath(const []);
    }
  }

  /// Revient au niveau parent direct.
  void _navigateUp() {
    if (_pathNodeIds.isNotEmpty) {
      final parentPath = _pathNodeIds.sublist(0, _pathNodeIds.length - 1);
      if (_historyPast.isNotEmpty && _pathEquals(_historyPast.last, parentPath)) {
        _goBack();
      } else {
        _navigateToPath(parentPath);
      }
    }
  }

  /// Revient à un niveau précis du fil d'Ariane.
  void _navigateToIndex(int index) {
    if (index < 0) {
      _goToRoot();
    } else if (index < _pathNodeIds.length - 1) {
      _navigateToPath(_pathNodeIds.sublist(0, index + 1));
    }
  }

  /// Ouvre directement un nœud en reconstituant tout son fil d'Ariane.
  void _jumpToNode(AcademicNode target, Map<String, AcademicNode> byId) {
    final ancestors = _getAncestors(target.id, byId);
    final newPath = ancestors.map((a) => a.id).toList()..add(target.id);
    _navigateToPath(newPath);
  }

  /// Pénètre dans un nœud enfant (navigation vers le niveau inférieur).
  void _enterNode(AcademicNode child) {
    _navigateToPath([..._pathNodeIds, child.id]);
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(academicTreeStreamProvider(_showInactive));

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (_canGoBack) _goBack();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          if (_canGoForward) _goForward();
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _canGoBack) {
              _goBack();
            }
          },
          child: treeAsync.when(
            data: (tree) {
              final byId = _flattenById(tree);
              _sanitizePath(byId);

              // Si la pile n'est pas vide et que le nœud terminal existe dans byId, on affiche
              // la vue pleine page dédiée à ce nœud.
              if (_pathNodeIds.isNotEmpty && byId.containsKey(_pathNodeIds.last)) {
                final currentNode = byId[_pathNodeIds.last]!;
                final breadcrumbNodes = _pathNodeIds
                    .map((id) => byId[id])
                    .whereType<AcademicNode>()
                    .toList();

                return _buildDedicatedNodeView(
                  context,
                  currentNode: currentNode,
                  breadcrumbNodes: breadcrumbNodes,
                  tree: tree,
                  byId: byId,
                );
              }

              // Sinon, on affiche la vue Racine (Accueil de l'arbre académique avec les Pays).
              return _buildRootView(context, tree: tree, byId: byId);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppTheme.accentRose,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement de l\'arbre académique',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$err',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.accentRose,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(academicTreeStreamProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // VUE RACINE : ACCUEIL ARBRE ACADÉMIQUE (LES PAYS)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildRootView(
    BuildContext context, {
    required List<AcademicNode> tree,
    required Map<String, AcademicNode> byId,
  }) {
    final searchResults = _searchQuery.isNotEmpty
        ? _searchAllNodes(tree, _searchQuery)
        : <AcademicNode>[];

    final totalNodesCount = byId.length;
    final totalCountries = tree.length;
    final archivedCount = byId.values.where((n) => !n.isActive).length;
    final toVerifyCount =
        byId.values.where((n) => n.verificationStatus != 'ok').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre de navigation d'historique unifiée (Précédent / Suivant / Racine)
          _buildNavigationToolbar(breadcrumbNodes: const []),
          const SizedBox(height: 20),

          // En-tête principal avec titre et actions globales
          _buildRootHeader(context, tree: tree),
          const SizedBox(height: 24),

          // Barre de métriques et KPI globaux
          _buildGlobalKpiRow(
            totalNodes: totalNodesCount,
            totalCountries: totalCountries,
            archivedCount: archivedCount,
            toVerifyCount: toVerifyCount,
          ),
          const SizedBox(height: 24),

          // Barre de recherche globale et filtre archivés
          _buildGlobalSearchFilterBar(),
          const SizedBox(height: 24),

          // Contenu principal : Résultats de recherche OU Grille des Pays
          if (_searchQuery.isNotEmpty)
            _buildGlobalSearchResultsSection(searchResults, byId)
          else
            _buildCountriesGridSection(tree, byId),
        ],
      ),
    );
  }

  Widget _buildRootHeader(
    BuildContext context, {
    required List<AcademicNode> tree,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1050;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
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
                        'Arbre Académique & Systèmes Éducatifs',
                        style: GoogleFonts.outfit(
                          fontSize: isCompact ? 22 : 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Structure hiérarchique à profondeur variable (Pays → Section → Enseignement → Classe → Série)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showAddNodeModal(
                context,
                parentNode: null,
                nodeTypeOptions: const [NodeType.country],
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Ajouter un Pays',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.primaryBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: tree.isEmpty
                  ? null
                  : () => _showMergeClassesModal(context, tree),
              icon: const Icon(
                Icons.call_merge_rounded,
                size: 18,
                color: AppTheme.accentIndigo,
              ),
              label: Text(
                'Fusionner des Classes',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.primaryBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: tree.isEmpty
                  ? null
                  : () => _showTwinGroupsModal(context, tree),
              icon: const Icon(
                Icons.link_rounded,
                size: 18,
                color: AppTheme.accentCyan,
              ),
              label: Text(
                'Jumeler des Classes',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 16),
              actionButtons,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 24),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildGlobalKpiRow({
    required int totalNodes,
    required int totalCountries,
    required int archivedCount,
    required int toVerifyCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth;
        if (constraints.maxWidth < 420) {
          cardWidth = constraints.maxWidth;
        } else if (constraints.maxWidth < 680) {
          cardWidth = (constraints.maxWidth - 12) / 2;
        } else {
          cardWidth = (constraints.maxWidth - 36) / 4;
        }

        final items = [
          _buildKpiCard(
            label: 'Nœuds au Total',
            value: '$totalNodes',
            icon: Icons.account_tree_outlined,
            color: AppTheme.accentBlue,
            width: cardWidth,
          ),
          _buildKpiCard(
            label: 'Pays Actifs / Déclarés',
            value: '$totalCountries',
            icon: Icons.public_rounded,
            color: AppTheme.accentEmerald,
            width: cardWidth,
          ),
          _buildKpiCard(
            label: 'Nœuds Archivés',
            value: '$archivedCount',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.accentAmber,
            width: cardWidth,
          ),
          _buildKpiCard(
            label: 'À Vérifier (Import)',
            value: '$toVerifyCount',
            icon: Icons.warning_amber_rounded,
            color: toVerifyCount > 0 ? AppTheme.accentRose : AppTheme.textMuted,
            width: cardWidth,
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items,
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onTap != null ? color.withValues(alpha: 0.5) : AppTheme.primaryBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }

  Widget _buildGlobalSearchFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        final searchField = Container(
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Rechercher n\'importe quel nœud (pays, section, classe, série)...',
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
          ),
        );

        final archiveSwitch = Container(
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
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Afficher les archivés',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: archiveSwitch),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 16),
            archiveSwitch,
          ],
        );
      },
    );
  }

  Widget _buildGlobalSearchResultsSection(
    List<AcademicNode> results,
    Map<String, AcademicNode> byId,
  ) {
    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun nœud ne correspond à "$_searchQuery"',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Essayez un autre mot-clé ou vérifiez que l\'élément n\'est pas archivé.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Résultats de la recherche',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${results.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final node = results[index];
            final fullPath = _nodePath(node, byId);
            final typeColor =
                nodeTypeColors[node.nodeType] ?? AppTheme.accentBlue;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _jumpToNode(node, byId),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          nodeTypeIcons[node.nodeType] ?? Icons.folder_rounded,
                          color: typeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    node.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    nodeTypeLabels[node.nodeType] ??
                                        node.nodeType.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                if (!node.isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentAmber
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'ARCHIVÉ',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentAmber,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fullPath,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.primaryBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _jumpToNode(node, byId),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Ouvrir'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCountriesGridSection(
    List<AcademicNode> countries,
    Map<String, AcademicNode> byId,
  ) {
    if (countries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.public_off_rounded,
              size: 52,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun pays configuré pour le moment',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Commencez par ajouter le premier pays pour structurer vos programmes éducatifs.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onPressed: () => _showAddNodeModal(
                context,
                parentNode: null,
                nodeTypeOptions: const [NodeType.country],
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un Premier Pays'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pays & Systèmes Nationaux',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sélectionnez un pays pour explorer ses sections, enseignements, classes et séries.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${countries.length} pays',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth;
            if (constraints.maxWidth >= 1050) {
              cardWidth = (constraints.maxWidth - 36) / 3;
            } else if (constraints.maxWidth >= 680) {
              cardWidth = (constraints.maxWidth - 18) / 2;
            } else {
              cardWidth = constraints.maxWidth;
            }

            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: countries
                  .map(
                    (country) => _buildCountryCard(
                      country: country,
                      width: cardWidth,
                      byId: byId,
                      allCountries: countries,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCountryCard({
    required AcademicNode country,
    required double width,
    required Map<String, AcademicNode> byId,
    required List<AcademicNode> allCountries,
  }) {
    final totalDescendants = _countDescendants(country);
    final directChildrenCount = country.children.length;

    final indexInCountries = allCountries.indexWhere((c) => c.id == country.id);
    final canMoveUp = indexInCountries > 0;
    final canMoveDown =
        indexInCountries >= 0 && indexInCountries < allCountries.length - 1;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: country.isActive
              ? AppTheme.primaryBorder
              : AppTheme.primaryBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _enterNode(country),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne du haut : Icône de pays, Nom, Badges et Menu contextuel
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
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
                            country.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: country.isActive
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (country.code != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppTheme.primaryBorder,
                                    ),
                                  ),
                                  child: Text(
                                    country.code!,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: country.isActive
                                      ? AppTheme.accentEmerald
                                          .withValues(alpha: 0.15)
                                      : AppTheme.accentAmber
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  country.isActive ? 'ACTIF' : 'ARCHIVÉ',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: country.isActive
                                        ? AppTheme.accentEmerald
                                        : AppTheme.accentAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      color: AppTheme.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.primaryBorder),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'edit':
                            _showEditNodeModal(context, country);
                            break;
                          case 'duplicate':
                            _duplicateNode(context, country);
                            break;
                          case 'up':
                            if (canMoveUp) {
                              _moveNode(allCountries, indexInCountries, -1);
                            }
                            break;
                          case 'down':
                            if (canMoveDown) {
                              _moveNode(allCountries, indexInCountries, 1);
                            }
                            break;
                          case 'archive':
                            _showDeactivateConfirmation(
                              context,
                              country,
                              ref.read(supabaseServiceProvider),
                            );
                            break;
                          case 'unarchive':
                            _showReactivateConfirmation(
                              context,
                              country,
                              ref.read(supabaseServiceProvider),
                            );
                            break;
                          case 'delete':
                            _showPermanentDeleteConfirmation(
                              context,
                              country,
                              ref.read(supabaseServiceProvider),
                            );
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 16),
                              SizedBox(width: 10),
                              Text('Modifier'),
                            ],
                          ),
                        ),
                        if (canMoveUp)
                          const PopupMenuItem(
                            value: 'up',
                            child: Row(
                              children: [
                                Icon(Icons.arrow_upward_rounded, size: 16),
                                SizedBox(width: 10),
                                Text('Monter dans l\'ordre'),
                              ],
                            ),
                          ),
                        if (canMoveDown)
                          const PopupMenuItem(
                            value: 'down',
                            child: Row(
                              children: [
                                Icon(Icons.arrow_downward_rounded, size: 16),
                                SizedBox(width: 10),
                                Text('Descendre dans l\'ordre'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 16),
                              SizedBox(width: 10),
                              Text('Dupliquer le pays'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        if (country.isActive)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_off_rounded,
                                  size: 16,
                                  color: AppTheme.accentAmber,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Archiver',
                                  style: TextStyle(color: AppTheme.accentAmber),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          const PopupMenuItem(
                            value: 'unarchive',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  size: 16,
                                  color: AppTheme.accentEmerald,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Désarchiver',
                                  style:
                                      TextStyle(color: AppTheme.accentEmerald),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  size: 16,
                                  color: AppTheme.accentRose,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Supprimer définitivement',
                                  style: TextStyle(color: AppTheme.accentRose),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Statistiques résumées du pays
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$directChildrenCount',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Éléments directs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: AppTheme.primaryBorder,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$totalDescendants',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                            Text(
                              'Total sous-nœuds',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bouton d'exploration vers la vue dédiée du pays
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.accentEmerald.withValues(alpha: 0.15),
                      foregroundColor: AppTheme.accentEmerald,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    onPressed: () => _enterNode(country),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Explorer le système',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
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

  // ══════════════════════════════════════════════════════════════════════════════
  // VUE DÉDIÉE PLEINE LARGEUR D'UN NŒUD (EXPLORATION PROGRESSIVE)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildDedicatedNodeView(
    BuildContext context, {
    required AcademicNode currentNode,
    required List<AcademicNode> breadcrumbNodes,
    required List<AcademicNode> tree,
    required Map<String, AcademicNode> byId,
  }) {
    final siblings =
        _findSiblingsGroup(tree, currentNode.id) ?? const <AcademicNode>[];
    final indexInSiblings = siblings.indexWhere((n) => n.id == currentNode.id);
    final canMoveUp = indexInSiblings > 0;
    final canMoveDown =
        indexInSiblings >= 0 && indexInSiblings < siblings.length - 1;

    final childTypes =
        childNodeTypeOptions[currentNode.nodeType] ?? const <NodeType>[];
    final totalDescendants = _countDescendants(currentNode);

    // Filtrage local des enfants si l'administrateur cherche dans la liste
    final visibleChildren = currentNode.children.where((c) {
      if (_childSearchQuery.isEmpty) return true;
      final q = _childSearchQuery.toLowerCase();
      final matchesName = c.name.toLowerCase().contains(q);
      final matchesCode = c.code != null && c.code!.toLowerCase().contains(q);
      return matchesName || matchesCode;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Barre de navigation unifiée (Précédent / Suivant / Racine / Fil d'Ariane)
          _buildNavigationToolbar(breadcrumbNodes: breadcrumbNodes),
          const SizedBox(height: 16),

          // 2. Bouton de retour bien visible vers le niveau supérieur
          _buildBackNavigationRow(breadcrumbNodes),
          const SizedBox(height: 20),

          // 3. Grande Hero Card dédiée au nœud courant
          _buildNodeHeroCard(
            context,
            node: currentNode,
            childTypes: childTypes,
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            siblings: siblings,
            indexInSiblings: indexInSiblings,
          ),
          const SizedBox(height: 24),

          // 4. Statistiques & indicateurs utiles du nœud
          _buildNodeStatsRow(
            context,
            currentNode: currentNode,
            totalDescendants: totalDescendants,
            byId: byId,
          ),
          const SizedBox(height: 28),

          // 5. Section des éléments enfants du nœud
          _buildChildNodesSection(
            context,
            currentNode: currentNode,
            visibleChildren: visibleChildren,
            allChildren: currentNode.children,
            childTypes: childTypes,
            byId: byId,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BARRE DE NAVIGATION UNIFIÉE (PRÉCÉDENT / SUIVANT / ACCUEIL / FIL D'ARIANE)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildNavigationToolbar({
    required List<AcademicNode> breadcrumbNodes,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final backBtn = _buildNavButton(
          label: isNarrow ? '' : 'Précédent',
          icon: Icons.arrow_back_rounded,
          tooltip: _canGoBack
              ? 'Page précédente (Alt + ←)'
              : 'Aucune page précédente',
          isEnabled: _canGoBack,
          isForward: false,
          onPressed: _canGoBack ? _goBack : null,
        );

        final forwardBtn = _buildNavButton(
          label: isNarrow ? '' : 'Suivant',
          icon: Icons.arrow_forward_rounded,
          tooltip: _canGoForward
              ? 'Page suivante (Alt + →)'
              : 'Aucune page suivante',
          isEnabled: _canGoForward,
          isForward: true,
          onPressed: _canGoForward ? _goForward : null,
        );

        final homeBtn = Tooltip(
          message: 'Retour à l\'accueil des Pays',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _pathNodeIds.isEmpty ? null : _goToRoot,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _pathNodeIds.isEmpty
                    ? AppTheme.accentEmerald.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _pathNodeIds.isEmpty
                      ? AppTheme.accentEmerald.withValues(alpha: 0.3)
                      : AppTheme.primaryBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home_rounded,
                    size: 16,
                    color: _pathNodeIds.isEmpty
                        ? AppTheme.accentEmerald
                        : (_canGoBack ? Colors.white70 : AppTheme.textMuted),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Racine',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _pathNodeIds.isEmpty
                            ? AppTheme.accentEmerald
                            : (_canGoBack ? Colors.white70 : AppTheme.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Contrôles de navigation historique
              backBtn,
              const SizedBox(width: 6),
              forwardBtn,
              const SizedBox(width: 6),
              homeBtn,

              // Séparateur vertical
              Container(
                height: 22,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppTheme.primaryBorder,
              ),

              // Fil d'Ariane interactif ou statut racine
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (breadcrumbNodes.isEmpty) ...[
                        const Icon(
                          Icons.account_tree_outlined,
                          size: 15,
                          color: AppTheme.accentEmerald,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Systèmes Éducatifs (Vue Racine)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentEmerald,
                          ),
                        ),
                      ] else ...[
                        // Racine cliquable
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _goToRoot,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_tree_outlined,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Arbre académique',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (int i = 0; i < breadcrumbNodes.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '›',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppTheme.textMuted.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final node = breadcrumbNodes[i];
                              final isLast = i == breadcrumbNodes.length - 1;
                              final typeColor =
                                  nodeTypeColors[node.nodeType] ??
                                  AppTheme.accentBlue;
                              final nodeIcon =
                                  nodeTypeIcons[node.nodeType] ??
                                  Icons.folder_rounded;

                              if (isLast) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: typeColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(nodeIcon, size: 14, color: typeColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        node.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _navigateToIndex(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        nodeIcon,
                                        size: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        node.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Raccourcis clavier discrets à droite
              if (!isNarrow) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.primaryBorder.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.keyboard_rounded,
                        size: 12,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Alt + ← / →',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required String tooltip,
    required bool isEnabled,
    required bool isForward,
    required VoidCallback? onPressed,
  }) {
    final activeBg = isForward
        ? AppTheme.accentEmerald.withValues(alpha: 0.12)
        : AppTheme.accentBlue.withValues(alpha: 0.12);
    final activeBorder = isForward
        ? AppTheme.accentEmerald.withValues(alpha: 0.35)
        : AppTheme.accentBlue.withValues(alpha: 0.35);
    final activeFg = isForward ? AppTheme.accentEmerald : AppTheme.accentBlue;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isEnabled ? activeBg : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled
                  ? activeBorder
                  : AppTheme.primaryBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isForward) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isEnabled
                      ? activeFg
                      : AppTheme.textMuted.withValues(alpha: 0.4),
                ),
                if (label.isNotEmpty) const SizedBox(width: 6),
              ],
              if (label.isNotEmpty)
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? Colors.white
                        : AppTheme.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              if (isForward) ...[
                if (label.isNotEmpty) const SizedBox(width: 6),
                Icon(
                  icon,
                  size: 16,
                  color: isEnabled
                      ? activeFg
                      : AppTheme.textMuted.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackNavigationRow(List<AcademicNode> breadcrumbNodes) {
    final parentName = breadcrumbNodes.length > 1
        ? breadcrumbNodes[breadcrumbNodes.length - 2].name
        : 'l\'accueil (Pays)';

    return Row(
      children: [
        Flexible(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.primaryBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _navigateUp,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(
              'Retour à $parentName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeHeroCard(
    BuildContext context, {
    required AcademicNode node,
    required List<NodeType> childTypes,
    required bool canMoveUp,
    required bool canMoveDown,
    required List<AcademicNode> siblings,
    required int indexInSiblings,
  }) {
    final typeColor = nodeTypeColors[node.nodeType] ?? AppTheme.accentBlue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne principale : Grand avatar, Nom, Métadonnées et Réordonnancement
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      nodeTypeIcons[node.nodeType] ?? Icons.folder_rounded,
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                node.name,
                                style: GoogleFonts.outfit(
                                  fontSize: isCompact ? 22 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Badge Type
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                nodeTypeLabels[node.nodeType] ??
                                    node.nodeType.name,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            // Badge Code
                            if (node.code != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryDark,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryBorder,
                                  ),
                                ),
                                child: Text(
                                  'CODE: ${node.code!}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            // Badge Statut Actif / Archivé
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: node.isActive
                                    ? AppTheme.accentEmerald
                                        .withValues(alpha: 0.15)
                                    : AppTheme.accentAmber
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                node.isActive ? 'ACTIF' : 'ARCHIVÉ',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: node.isActive
                                      ? AppTheme.accentEmerald
                                      : AppTheme.accentAmber,
                                ),
                              ),
                            ),
                            // Badge Vérification si importé
                            if (node.verificationStatus != 'ok')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentAmber
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  node.verificationStatus == 'incomplete'
                                      ? 'INCOMPLET'
                                      : 'À VÉRIFIER',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentAmber,
                                  ),
                                ),
                              ),
                            // ID Copiable
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: node.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('ID copié dans le presse-papier'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Tooltip(
                                message: 'Cliquer pour copier l\'ID complet',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppTheme.primaryBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.copy_rounded,
                                        size: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ID: ${node.id.substring(0, 8)}...',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (siblings.length > 1) ...[
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                            tooltip: 'Monter dans l\'ordre',
                            color: canMoveUp ? Colors.white : Colors.white24,
                            onPressed: canMoveUp
                                ? () => _moveNode(siblings, indexInSiblings, -1)
                                : null,
                          ),
                          Container(
                            height: 18,
                            width: 1,
                            color: AppTheme.primaryBorder,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                            ),
                            tooltip: 'Descendre dans l\'ordre',
                            color: canMoveDown ? Colors.white : Colors.white24,
                            onPressed: canMoveDown
                                ? () => _moveNode(siblings, indexInSiblings, 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 18),

              // Barre des actions opérationnelles sur ce nœud
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (childTypes.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showAddNodeModal(
                        context,
                        parentNode: node,
                        nodeTypeOptions: childTypes,
                      ),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 17,
                      ),
                      label: Text(
                        childTypes.length == 1
                            ? 'Ajouter ${nodeTypeLabels[childTypes.first]}'
                            : 'Ajouter un sous-élément',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.primaryBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showEditNodeModal(context, node),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Modifier'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.primaryBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _duplicateNode(context, node),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Dupliquer le sous-arbre'),
                  ),
                  if (node.isActive)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentAmber,
                        side: const BorderSide(color: AppTheme.accentAmber),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showDeactivateConfirmation(
                        context,
                        node,
                        ref.read(supabaseServiceProvider),
                      ),
                      icon: const Icon(
                        Icons.visibility_off_rounded,
                        size: 16,
                        color: AppTheme.accentAmber,
                      ),
                      label: const Text('Archiver'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentEmerald,
                        side: const BorderSide(color: AppTheme.accentEmerald),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showReactivateConfirmation(
                        context,
                        node,
                        ref.read(supabaseServiceProvider),
                      ),
                      icon: const Icon(
                        Icons.visibility_rounded,
                        size: 16,
                        color: AppTheme.accentEmerald,
                      ),
                      label: const Text('Désarchiver'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRose,
                        side: const BorderSide(color: AppTheme.accentRose),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showPermanentDeleteConfirmation(
                        context,
                        node,
                        ref.read(supabaseServiceProvider),
                      ),
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        size: 16,
                        color: AppTheme.accentRose,
                      ),
                      label: const Text('Supprimer Définitivement'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNodeStatsRow(
    BuildContext context, {
    required AcademicNode currentNode,
    required int totalDescendants,
    required Map<String, AcademicNode> byId,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth;
        if (constraints.maxWidth < 420) {
          cardWidth = constraints.maxWidth;
        } else if (constraints.maxWidth < 680) {
          cardWidth = (constraints.maxWidth - 12) / 2;
        } else {
          cardWidth = (constraints.maxWidth - 36) / 4;
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              label: 'Enfants Directs',
              value: '${currentNode.children.length}',
              icon: Icons.subdirectory_arrow_right_rounded,
              color: AppTheme.accentBlue,
              width: cardWidth,
            ),
            _buildKpiCard(
              label: 'Descendants Totaux',
              value: '$totalDescendants',
              icon: Icons.hub_rounded,
              color: AppTheme.accentIndigo,
              width: cardWidth,
            ),
            // Compte réel des profils élèves rattachés
            FutureBuilder<int>(
              future: _countProfiles(currentNode.id),
              builder: (context, snapshot) {
                final valueText = snapshot.connectionState ==
                        ConnectionState.waiting
                    ? '...'
                    : (snapshot.hasError ? '—' : '${snapshot.data ?? 0}');
                return _buildKpiCard(
                  label: 'Élèves Rattachés',
                  value: valueText,
                  icon: Icons.people_outline_rounded,
                  color: AppTheme.accentEmerald,
                  width: cardWidth,
                );
              },
            ),
            // Matières enseignées si c'est une classe, une série ou une spécialité
            // (les filières techniques/professionnelles rattachent le contenu au
            // niveau spécialité plutôt qu'au niveau série — migration 88).
            if (currentNode.nodeType == NodeType.classType ||
                currentNode.nodeType == NodeType.series ||
                currentNode.nodeType == NodeType.specialty)
              Consumer(
                builder: (context, ref, _) {
                  final subjectsAsync =
                      ref.watch(subjectsForClassProvider(currentNode.id));
                  final valueText = subjectsAsync.when(
                    data: (subs) => '${subs.length}',
                    loading: () => '...',
                    error: (_, _) => '—',
                  );
                  return _buildKpiCard(
                    label: 'Matières Associées',
                    value: valueText,
                    icon: Icons.menu_book_rounded,
                    color: AppTheme.accentCyan,
                    width: cardWidth,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectsByClassScreen(
                          node: currentNode,
                          displayLabel: describeNodeWithAncestorClass(currentNode, byId),
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              _buildKpiCard(
                label: 'Niveau Hiérarchique',
                value: nodeTypeLabels[currentNode.nodeType] ?? '',
                icon: Icons.layers_outlined,
                color: AppTheme.textMuted,
                width: cardWidth,
              ),
          ],
        );
      },
    );
  }

  Widget _buildChildNodesSection(
    BuildContext context, {
    required AcademicNode currentNode,
    required List<AcademicNode> visibleChildren,
    required List<AcademicNode> allChildren,
    required List<NodeType> childTypes,
    required Map<String, AcademicNode> byId,
  }) {
    // Cas 1 : Niveau terminal (Série)
    if (childTypes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 32,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Niveau Terminal de l\'Arbre Académique',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Text(
                'Une Série est le niveau le plus fin de l\'arborescence. Aucun sous-nœud académique ne '
                'peut y être rattaché. C\'est à ce niveau que sont rattachées les Matières, Chapitres, '
                'Leçons, Exercices et Épreuves d\'examens.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Cas 2 : Nœud sans aucun enfant pour le moment
    if (allChildren.isEmpty) {
      final targetChildLabel = childTypes.length == 1
          ? nodeTypeLabels[childTypes.first]
          : 'sous-élément';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun élément enfant rattaché à "${currentNode.name}"',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ajoutez le premier $targetChildLabel pour continuer la configuration de ce palier.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showAddNodeModal(
                context,
                parentNode: currentNode,
                nodeTypeOptions: childTypes,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text('Ajouter un $targetChildLabel'),
            ),
          ],
        ),
      );
    }

    // Cas 3 : Liste des enfants existants
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Éléments Rattachés',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${allChildren.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cliquez sur un élément pour explorer son sous-niveau complet.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (childTypes.isNotEmpty) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showAddNodeModal(
                  context,
                  parentNode: currentNode,
                  nodeTypeOptions: childTypes,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Ajouter'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Filtre rapide des enfants si plus de 3 enfants
        if (allChildren.length > 3) ...[
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: TextField(
              controller: _childSearchController,
              onChanged: (v) => setState(() => _childSearchQuery = v.trim()),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Filtrer les éléments par nom ou code...',
                hintStyle: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.filter_list_rounded,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
                suffixIcon: _childSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(() {
                          _childSearchController.clear();
                          _childSearchQuery = '';
                        }),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Grille responsive des cartes enfants
        if (visibleChildren.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Aucun élément ne correspond à "$_childSearchQuery".',
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth >= 1050) {
                cardWidth = (constraints.maxWidth - 36) / 3;
              } else if (constraints.maxWidth >= 680) {
                cardWidth = (constraints.maxWidth - 18) / 2;
              } else {
                cardWidth = constraints.maxWidth;
              }

              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: visibleChildren
                    .map(
                      (child) => _buildChildNodeCard(
                        childNode: child,
                        width: cardWidth,
                        siblings: allChildren,
                        byId: byId,
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildChildNodeCard({
    required AcademicNode childNode,
    required double width,
    required List<AcademicNode> siblings,
    required Map<String, AcademicNode> byId,
  }) {
    final typeColor = nodeTypeColors[childNode.nodeType] ?? AppTheme.accentBlue;
    final totalSubDescendants = _countDescendants(childNode);
    final directChildren = childNode.children.length;

    final indexInSiblings = siblings.indexWhere((s) => s.id == childNode.id);
    final canMoveUp = indexInSiblings > 0;
    final canMoveDown =
        indexInSiblings >= 0 && indexInSiblings < siblings.length - 1;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: childNode.isActive
              ? AppTheme.primaryBorder
              : AppTheme.primaryBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _enterNode(childNode),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        nodeTypeIcons[childNode.nodeType] ??
                            Icons.folder_rounded,
                        color: typeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            childNode.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: childNode.isActive
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  nodeTypeLabels[childNode.nodeType] ??
                                      childNode.nodeType.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              if (childNode.code != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppTheme.primaryBorder,
                                    ),
                                  ),
                                  child: Text(
                                    childNode.code!,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              if (!childNode.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentAmber
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ARCHIVÉ',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentAmber,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                      color: AppTheme.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.primaryBorder),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'edit':
                            _showEditNodeModal(context, childNode);
                            break;
                          case 'duplicate':
                            _duplicateNode(context, childNode);
                            break;
                          case 'up':
                            if (canMoveUp) {
                              _moveNode(siblings, indexInSiblings, -1);
                            }
                            break;
                          case 'down':
                            if (canMoveDown) {
                              _moveNode(siblings, indexInSiblings, 1);
                            }
                            break;
                          case 'archive':
                            _showDeactivateConfirmation(
                              context,
                              childNode,
                              ref.read(supabaseServiceProvider),
                            );
                            break;
                          case 'unarchive':
                            _showReactivateConfirmation(
                              context,
                              childNode,
                              ref.read(supabaseServiceProvider),
                            );
                            break;
                          case 'delete':
                            _showPermanentDeleteConfirmation(
                              context,
                              childNode,
                              ref.read(supabaseServiceProvider),
                            );
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 16),
                              SizedBox(width: 10),
                              Text('Modifier'),
                            ],
                          ),
                        ),
                        if (canMoveUp)
                          const PopupMenuItem(
                            value: 'up',
                            child: Row(
                              children: [
                                Icon(Icons.arrow_upward_rounded, size: 16),
                                SizedBox(width: 10),
                                Text('Monter'),
                              ],
                            ),
                          ),
                        if (canMoveDown)
                          const PopupMenuItem(
                            value: 'down',
                            child: Row(
                              children: [
                                Icon(Icons.arrow_downward_rounded, size: 16),
                                SizedBox(width: 10),
                                Text('Descendre'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 16),
                              SizedBox(width: 10),
                              Text('Dupliquer'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        if (childNode.isActive)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_off_rounded,
                                  size: 16,
                                  color: AppTheme.accentAmber,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Archiver',
                                  style: TextStyle(color: AppTheme.accentAmber),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          const PopupMenuItem(
                            value: 'unarchive',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  size: 16,
                                  color: AppTheme.accentEmerald,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Désarchiver',
                                  style:
                                      TextStyle(color: AppTheme.accentEmerald),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  size: 16,
                                  color: AppTheme.accentRose,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Supprimer définitivement',
                                  style: TextStyle(color: AppTheme.accentRose),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Ligne d'information : nombre d'enfants
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      directChildren > 0
                          ? '$directChildren élément(s) rattaché(s)'
                          : 'Aucun sous-élément',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (totalSubDescendants > directChildren)
                      Text(
                        '($totalSubDescendants total)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bouton d'action "Explorer"
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.primaryBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _enterNode(childNode),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Explorer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 14),
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

  // ══════════════════════════════════════════════════════════════════════════════
  // LOGIQUES MÉTIERS, ACTIONS & MODALES (100% NON-RÉGRESSION)
  // ══════════════════════════════════════════════════════════════════════════════

  List<AcademicNode>? _findSiblingsGroup(
    List<AcademicNode> nodes,
    String targetId,
  ) {
    if (nodes.any((n) => n.id == targetId)) return nodes;
    for (final n in nodes) {
      final found = _findSiblingsGroup(n.children, targetId);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _moveNode(
    List<AcademicNode> siblings,
    int index,
    int direction,
  ) async {
    final other = siblings[index + direction];
    final current = siblings[index];
    final service = ref.read(supabaseServiceProvider);
    try {
      await service.updateNodeOrder(current.id, other.displayOrder);
      await service.updateNodeOrder(other.id, current.displayOrder);
      ref.invalidate(academicTreeStreamProvider);
      ref.invalidate(nodesByTypeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text('Erreur lors du réordonnancement : $e'),
          ),
        );
      }
    }
  }

  void _showAddNodeModal(
    BuildContext context, {
    required AcademicNode? parentNode,
    required List<NodeType> nodeTypeOptions,
  }) {
    assert(
      nodeTypeOptions.isNotEmpty,
      'nodeTypeOptions ne doit jamais être vide ici',
    );
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final parentNodeName = parentNode?.name ?? 'Racine';
    NodeType selectedNodeType = nodeTypeOptions.first;
    final parentId = parentNode?.id;
    final countryId = parentNode == null
        ? null
        : (parentNode.nodeType == NodeType.country
            ? parentNode.id
            : parentNode.countryId);
    String? fieldError;
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
            icon: nodeTypeIcons[selectedNodeType] ??
                Icons.add_circle_outline_rounded,
            iconColor:
                nodeTypeColors[selectedNodeType] ?? AppTheme.accentEmerald,
            text:
                'Ajouter ${nodeTypeLabels[selectedNodeType] ?? selectedNodeType.name}',
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
                    'Sous "$parentNodeName"',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (nodeTypeOptions.length > 1) ...[
                    const SizedBox(height: 16),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<NodeType>(
                      // ignore: deprecated_member_use
                      value: selectedNodeType,
                      dropdownColor: AppTheme.primaryDark,
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type de nœud',
                        helperText:
                            'Vous pouvez sauter des niveaux intermédiaires si besoin',
                        prefixIcon: Icon(Icons.account_tree_rounded, size: 20),
                      ),
                      items: nodeTypeOptions
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(nodeTypeLabels[t] ?? t.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(
                        () => selectedNodeType = v ?? selectedNodeType,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom de l\'entité',
                      hintText: 'ex: Classe de 3ème',
                      prefixIcon: const Icon(
                        Icons.drive_file_rename_outline_rounded,
                        size: 20,
                      ),
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Code court (optionnel)',
                      hintText: 'ex: 3E',
                      prefixIcon: Icon(Icons.tag_rounded, size: 20),
                    ),
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
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setModalState(
                          () => fieldError = 'Le nom est obligatoire',
                        );
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createNode(
                          parentId: parentId,
                          name: name,
                          nodeType: nodeTypeToDb(selectedNodeType),
                          code: codeController.text.trim().isEmpty
                              ? null
                              : codeController.text.trim(),
                          countryId: countryId,
                          displayOrder: 0,
                        );
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
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
                  : const Text('Créer l\'élément'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateNode(BuildContext context, AcademicNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.copy_rounded,
          iconColor: AppTheme.accentIndigo,
          text: 'Dupliquer "${node.name}" ?',
          onClose: () => Navigator.pop(ctx, false),
        ),
        content: SizedBox(
          width: 440,
          child: Text(
            'Ce nœud et tout son sous-arbre (enfants, petits-enfants...) seront copiés à côté de '
            'l\'original, archivés par défaut le temps de la relecture.',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.4),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentIndigo,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dupliquer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.duplicateAcademicNode(node.id);
      setState(() => _showInactive = true);
      ref.invalidate(academicTreeStreamProvider);
      ref.invalidate(nodesByTypeProvider);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text(
            '"${node.name}" dupliqué avec son sous-arbre (copie inactive — activez-la depuis "Modifier" après relecture).',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentRose,
          content: Text('Erreur lors de la duplication : $e'),
        ),
      );
    }
  }

  void _showEditNodeModal(BuildContext context, AcademicNode node) {
    final nameController = TextEditingController(text: node.name);
    final codeController = TextEditingController(text: node.code ?? '');
    bool isActive = node.isActive;
    String? fieldError;
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
            icon: Icons.edit_rounded,
            iconColor: AppTheme.accentBlue,
            text: 'Modifier "${node.name}"',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom de l\'entité',
                      prefixIcon: const Icon(
                        Icons.drive_file_rename_outline_rounded,
                        size: 20,
                      ),
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Code court',
                      prefixIcon: Icon(Icons.tag_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        activeThumbColor: AppTheme.accentEmerald,
                        secondary: Icon(
                          isActive
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: isActive
                              ? AppTheme.accentEmerald
                              : Colors.white38,
                          size: 20,
                        ),
                        title: Text(
                          'Nœud actif',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isActive
                              ? 'Visible dans l\'application'
                              : 'Masqué aux élèves',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        value: isActive,
                        onChanged: (v) => setModalState(() => isActive = v),
                      ),
                    ),
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
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setModalState(
                          () => fieldError = 'Le nom est obligatoire',
                        );
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateNode(
                          node.id,
                          name: name,
                          code: codeController.text.trim(),
                          isActive: isActive,
                        );
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
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
                  : const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateConfirmation(
    BuildContext context,
    AcademicNode node,
    SupabaseService service,
  ) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.visibility_off_rounded,
            iconColor: AppTheme.accentAmber,
            text: 'Archiver "${node.name}" ?',
            onClose: () => Navigator.pop(context),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Le nœud sera masqué aux élèves, pas supprimé — vous pourrez le désarchiver ou le '
                    'supprimer définitivement plus tard. Impact :',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.accentAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${node.children.length} nœud(s) enfant(s) rattaché(s) (également archivés)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                        FutureBuilder<int>(
                          future: service.countProfilesForNode(node.id),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text(
                                '• Calcul du nombre d\'élèves concernés...',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              );
                            }
                            final count = snapshot.data!;
                            return Text(
                              count == 0
                                  ? '• Aucun élève rattaché directement à ce nœud'
                                  : '• $count élève(s) rattaché(s) directement à ce nœud seront masqués',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: count == 0
                                    ? AppTheme.textMuted
                                    : AppTheme.accentAmber,
                                fontWeight: count == 0
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        Text(
                          '• Une entrée d\'audit sera enregistrée sous votre compte',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final nav = Navigator.of(context);
                      try {
                        await service.deactivateNode(
                          node.id,
                          _currentAdminId(),
                        );
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        nav.pop();
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentRose,
                              content: Text('Erreur : $e'),
                            ),
                          );
                        }
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
                  : const Text('Archiver'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactivateConfirmation(
    BuildContext context,
    AcademicNode node,
    SupabaseService service,
  ) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.visibility_rounded,
            iconColor: AppTheme.accentEmerald,
            text: 'Désarchiver "${node.name}" ?',
            onClose: () => Navigator.pop(context),
          ),
          content: SizedBox(
            width: 440,
            child: Text(
              'Ce nœud ET tous ses descendants redeviendront actifs et visibles dans l\'application '
              '(un simple "Modifier" ne désarchive que ce nœud seul, pas ses enfants).',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final nav = Navigator.of(context);
                      try {
                        await service.reactivateNode(
                          node.id,
                          _currentAdminId(),
                        );
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        nav.pop();
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentRose,
                              content: Text('Erreur : $e'),
                            ),
                          );
                        }
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
                  : const Text('Désarchiver'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermanentDeleteConfirmation(
    BuildContext context,
    AcademicNode node,
    SupabaseService service,
  ) {
    bool isLoading = false;
    String? errorText;
    final confirmController = TextEditingController();
    bool nameMatches = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.accentRose,
            text: 'Supprimer définitivement "${node.name}" ?',
            onClose: () => Navigator.pop(context),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.accentRose.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'IRRÉVERSIBLE : ce nœud et tout son sous-arbre (${node.children.length} '
                      'enfant(s) direct(s)) seront physiquement supprimés de la base, avec tout leur '
                      'contenu rattaché (chapitres, exercices, examens...). Refusé automatiquement '
                      's\'il reste des élèves inscrits dessus.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.accentRose,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tapez "${node.name}" pour confirmer :',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: node.name,
                      prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                    ),
                    onChanged: (v) => setModalState(
                      () => nameMatches = v.trim() == node.name,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: errorText!),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
              ),
              onPressed: (isLoading || !nameMatches)
                  ? null
                  : () async {
                      setModalState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      final nav = Navigator.of(context);
                      try {
                        await service.permanentlyDeleteNode(
                          node.id,
                          _currentAdminId(),
                        );
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        if (mounted) {
                          _navigateUp();
                        }
                        nav.pop();
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
                  : const Text('Supprimer définitivement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMergeClassesModal(BuildContext context, List<AcademicNode> tree) {
    final byId = _flattenById(tree);
    final mergeable = byId.values
        .where(
          (n) =>
              n.nodeType == NodeType.classType || n.nodeType == NodeType.series,
        )
        .toList()
      ..sort((a, b) => _nodePath(a, byId).compareTo(_nodePath(b, byId)));

    if (mergeable.length < 2) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.accentAmber,
            text: 'Fusion impossible',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 400,
            child: Text(
              'Il faut au moins deux Classes ou Séries dans l\'arbre pour effectuer une fusion.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.4),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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

    String? sourceId;
    String? targetId;
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
            icon: Icons.call_merge_rounded,
            iconColor: AppTheme.accentIndigo,
            text: 'Fusionner deux Classes / Séries',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentIndigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.accentIndigo.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Les élèves, rattachements matière, chapitres, exercices, paliers, examens, '
                      'communautés et documents de la classe SOURCE seront transférés vers la classe '
                      'CIBLE. La classe source sera ensuite archivée (pas supprimée). Action '
                      'réservée aux deux nœuds de même type (Classe avec Classe, ou Série avec '
                      'Série). Pour partager du contenu SANS fusionner ni archiver de classe, '
                      'utilisez plutôt "Jumeler des Classes".',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: sourceId,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Classe SOURCE (sera archivée)',
                      prefixIcon: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppTheme.accentRose,
                        size: 20,
                      ),
                    ),
                    items: mergeable
                        .map(
                          (n) => DropdownMenuItem(
                            value: n.id,
                            child: Text(
                              _nodePath(n, byId),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => sourceId = v),
                  ),
                  const SizedBox(height: 16),
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: targetId,
                    dropdownColor: AppTheme.primaryDark,
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Classe CIBLE (conservée)',
                      prefixIcon: Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppTheme.accentEmerald,
                        size: 20,
                      ),
                    ),
                    items: mergeable
                        .map(
                          (n) => DropdownMenuItem(
                            value: n.id,
                            child: Text(
                              _nodePath(n, byId),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => targetId = v),
                  ),
                  if (sourceId != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Impact sur la classe SOURCE :',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Consumer(
                      builder: (context, ref, _) {
                        final impactAsync = ref.watch(
                          classNodeMergeImpactProvider(sourceId!),
                        );
                        return impactAsync.when(
                          data: (rows) {
                            final nonZero =
                                rows.where((r) => r.rowCount > 0).toList();
                            if (nonZero.isEmpty) {
                              return Text(
                                'Aucune donnée rattachée à cette classe.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: nonZero
                                  .map(
                                    (r) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentAmber.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${r.entityLabel} : ${r.rowCount}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.accentAmber,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
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
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: errorText!),
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
                      if (sourceId == null || targetId == null) {
                        setModalState(
                          () => errorText = 'Sélectionnez les deux classes.',
                        );
                        return;
                      }
                      if (sourceId == targetId) {
                        setModalState(
                          () => errorText =
                              'La source et la cible doivent être différentes.',
                        );
                        return;
                      }
                      if (byId[sourceId]!.nodeType !=
                          byId[targetId]!.nodeType) {
                        setModalState(
                          () => errorText =
                              'Les deux nœuds doivent être du même type.',
                        );
                        return;
                      }
                      setModalState(() {
                        errorText = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.mergeClassNodes(
                          sourceId: sourceId!,
                          targetId: targetId!,
                          adminId: _currentAdminId(),
                        );
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        ref.invalidate(subjectsForClassProvider);
                        ref.invalidate(classesForSubjectProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                '"${byId[sourceId]?.name}" fusionné dans "${byId[targetId]?.name}".',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = 'Erreur : $e';
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
                  : const Text('Confirmer la Fusion'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTwinGroupsModal(BuildContext context, List<AcademicNode> tree) {
    final byId = _flattenById(tree);
    final candidates = byId.values
        .where(
          (n) =>
              n.nodeType == NodeType.classType || n.nodeType == NodeType.series,
        )
        .toList()
      ..sort((a, b) => _nodePath(a, byId).compareTo(_nodePath(b, byId)));

    Set<String> newGroupSelection = {};
    final labelController = TextEditingController();
    String? selectedSubjectId;
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
            text: 'Classes Jumelées',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 560,
            height: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Déclarer que plusieurs classes/séries partagent le même programme, sans les '
                      'fusionner ni en archiver aucune. Une fois jumelées, dupliquer un chapitre '
                      'vers "toutes les classes jumelées" devient possible en un clic depuis '
                      'Chapitres & Leçons.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Groupes existants',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final groupsAsync = ref.watch(twinGroupsProvider);
                      return groupsAsync.when(
                        data: (groups) {
                          if (groups.isEmpty) {
                            return Text(
                              'Aucun groupe déclaré pour le moment.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            );
                          }
                          return Column(
                            children: groups
                                .map(
                                  (g) => Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryDark,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.primaryBorder,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    g.label?.isNotEmpty == true
                                                        ? g.label!
                                                        : 'Groupe sans nom',
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  if (g.subjectName != null)
                                                    Text(
                                                      'Matière : ${g.subjectName}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        color:
                                                            AppTheme.accentCyan,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: isLoading
                                                  ? null
                                                  : () async {
                                                      final confirm =
                                                          await showDialog<bool>(
                                                        context: context,
                                                        builder: (c) =>
                                                            AlertDialog(
                                                          backgroundColor:
                                                              AppTheme
                                                                  .primarySurface,
                                                          title: AppDialogTitle(
                                                            icon: Icons
                                                                .link_off_rounded,
                                                            iconColor: AppTheme
                                                                .accentRose,
                                                            text:
                                                                'Dissoudre ce groupe ?',
                                                            onClose: () =>
                                                                Navigator.pop(
                                                              c,
                                                              false,
                                                            ),
                                                          ),
                                                          content: Text(
                                                            'Les classes ne seront plus considérées comme jumelées. Aucune donnée existante n\'est supprimée.',
                                                            style: GoogleFonts
                                                                .inter(
                                                              color: Colors
                                                                  .white70,
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                c,
                                                                false,
                                                              ),
                                                              child: const Text(
                                                                'Annuler',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    AppTheme
                                                                        .accentRose,
                                                              ),
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                c,
                                                                true,
                                                              ),
                                                              child: const Text(
                                                                'Dissoudre',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm != true) {
                                                        return;
                                                      }
                                                      final service = ref.read(
                                                        supabaseServiceProvider,
                                                      );
                                                      await service
                                                          .dissolveClassTwinGroup(
                                                        g.id,
                                                        _currentAdminId(),
                                                      );
                                                      ref.invalidate(
                                                        twinGroupsProvider,
                                                      );
                                                      ref.invalidate(
                                                        twinGroupForClassProvider,
                                                      );
                                                    },
                                              icon: const Icon(
                                                Icons.link_off_rounded,
                                                size: 14,
                                                color: AppTheme.accentRose,
                                              ),
                                              label: Text(
                                                'Dissoudre',
                                                style: GoogleFonts.inter(
                                                  color: AppTheme.accentRose,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: g.members
                                              .map(
                                                (m) => Chip(
                                                  label: Text(
                                                    m.className,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  backgroundColor: AppTheme
                                                      .accentCyan
                                                      .withValues(alpha: 0.15),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  deleteIcon: const Icon(
                                                    Icons.close_rounded,
                                                    size: 14,
                                                  ),
                                                  onDeleted: isLoading
                                                      ? null
                                                      : () async {
                                                          final service = ref.read(
                                                            supabaseServiceProvider,
                                                          );
                                                          await service
                                                              .removeClassFromTwinGroup(
                                                            g.id,
                                                            m.classNodeId,
                                                            _currentAdminId(),
                                                          );
                                                          ref.invalidate(
                                                            twinGroupsProvider,
                                                          );
                                                          ref.invalidate(
                                                            twinGroupForClassProvider,
                                                          );
                                                        },
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text(
                          'Erreur: $err',
                          style: GoogleFonts.inter(
                            color: AppTheme.accentRose,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.primaryBorder),
                  const SizedBox(height: 12),
                  Text(
                    'Déclarer un nouveau groupe',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Un jumelage porte toujours sur une matière précise — les mêmes classes peuvent '
                    'être jumelées en Maths sans l\'être en Français.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(
                        subjectsProvider((
                          countryId: null,
                          includeInactive: false,
                        )),
                      );
                      final subjects = subjectsAsync.valueOrNull ?? [];
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: selectedSubjectId,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Matière concernée',
                          prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                        ),
                        items: subjects
                            .map(
                              (s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedSubjectId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText:
                          'Nom du groupe (optionnel, ex: Terminale C parallèles)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...candidates.map(
                    (c) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: newGroupSelection.contains(c.id),
                      activeColor: AppTheme.accentCyan,
                      title: Text(
                        _nodePath(c, byId),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      onChanged: (checked) => setModalState(() {
                        if (checked == true) {
                          newGroupSelection.add(c.id);
                        } else {
                          newGroupSelection.remove(c.id);
                        }
                      }),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: errorText!),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedSubjectId == null) {
                        setModalState(
                          () => errorText =
                              'La matière concernée est obligatoire.',
                        );
                        return;
                      }
                      if (newGroupSelection.length < 2) {
                        setModalState(
                          () => errorText =
                              'Sélectionnez au moins 2 classes/séries.',
                        );
                        return;
                      }
                      final types = newGroupSelection
                          .map((id) => byId[id]!.nodeType)
                          .toSet();
                      if (types.length > 1) {
                        setModalState(
                          () => errorText =
                              'Toutes les classes du groupe doivent être du même type.',
                        );
                        return;
                      }
                      setModalState(() {
                        errorText = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.declareClassTwinGroup(
                          newGroupSelection.toList(),
                          selectedSubjectId!,
                          labelController.text.trim().isEmpty
                              ? null
                              : labelController.text.trim(),
                          _currentAdminId(),
                        );
                        ref.invalidate(twinGroupsProvider);
                        ref.invalidate(twinGroupForClassProvider);
                        setModalState(() {
                          isLoading = false;
                          newGroupSelection = {};
                          selectedSubjectId = null;
                          labelController.clear();
                        });
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = 'Erreur : $e';
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
                  : const Icon(Icons.add_link_rounded, size: 16),
              label: const Text('Créer le groupe'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'erreur réutilisable pour les formulaires de cette page.
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
