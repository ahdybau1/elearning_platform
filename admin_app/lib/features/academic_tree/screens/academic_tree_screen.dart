import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class AcademicTreeScreen extends ConsumerStatefulWidget {
  const AcademicTreeScreen({super.key});

  @override
  ConsumerState<AcademicTreeScreen> createState() => _AcademicTreeScreenState();
}

class _AcademicTreeScreenState extends ConsumerState<AcademicTreeScreen> {
  String? _selectedNodeId;
  AcademicNode? _selectedNode;
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

  /// Reconstruit la carte id → nœud à partir de l'arbre chargé, pour retrouver un nœud
  /// sélectionné après un rafraîchissement (le stream Supabase reconstruit toute la liste)
  /// et pour calculer des chemins hiérarchiques complets (fusion de classes).
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

  String _nodePath(AcademicNode node, Map<String, AcademicNode> byId) {
    final parts = <String>[node.name];
    var current = node;
    while (current.parentId != null && byId.containsKey(current.parentId)) {
      current = byId[current.parentId]!;
      parts.add(current.name);
    }
    return parts.reversed.join(' › ');
  }

  bool _matchesSearch(AcademicNode node, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (node.name.toLowerCase().contains(q)) return true;
    if (node.code != null && node.code!.toLowerCase().contains(q)) return true;
    return node.children.any((c) => _matchesSearch(c, query));
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(academicTreeStreamProvider(_showInactive));

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
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
                      'Gestion de l\'Arbre Académique',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Structure générique à profondeur variable (Pays → Section → Enseignement → Classe → Série)',
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
                    onPressed: () => _showAddNodeModal(
                      context,
                      parentNode: null,
                      nodeTypeOptions: const [NodeType.country],
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter un Pays'),
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
                    onPressed: treeAsync.valueOrNull == null
                        ? null
                        : () => _showMergeClassesModal(context, treeAsync.valueOrNull!),
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
                    onPressed: treeAsync.valueOrNull == null
                        ? null
                        : () => _showTwinGroupsModal(context, treeAsync.valueOrNull!),
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
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Barre de recherche + filtre d'archivés
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
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un nœud par nom ou code...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
                  Text(
                    'Afficher les nœuds archivés',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: treeAsync.when(
                    data: (tree) {
                      final byId = _flattenById(tree);
                      // Resynchronise la fiche sélectionnée avec les données fraîches du stream
                      // (ex: après un renommage) sans perdre la sélection.
                      if (_selectedNodeId != null && byId.containsKey(_selectedNodeId)) {
                        _selectedNode = byId[_selectedNodeId];
                      } else if (_selectedNodeId != null) {
                        _selectedNodeId = null;
                        _selectedNode = null;
                      }

                      final visibleRoots =
                          tree.where((n) => _matchesSearch(n, _searchQuery)).toList();

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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Arborescence Académique',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${byId.length} nœud(s)',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 14,
                              runSpacing: 6,
                              children: NodeType.values
                                  .map((t) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: nodeTypeColors[t] ?? AppTheme.textMuted,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            nodeTypeLabels[t] ?? t.name,
                                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            Expanded(
                              child: tree.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Aucun pays configuré. Cliquez sur "Ajouter un Pays" pour commencer.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    )
                                  : visibleRoots.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Aucun résultat pour "$_searchQuery".',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        )
                                      : ListView(
                                          children: visibleRoots
                                              .map(
                                                (node) => _buildTreeNodeWidget(
                                                  node,
                                                  level: 0,
                                                ),
                                              )
                                              .toList(),
                                        ),
                            ),
                          ],
                        ),
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
                const SizedBox(width: 24),

                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryBorder),
                    ),
                    child: _selectedNode == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.touch_app_rounded,
                                  size: 48,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sélectionnez un nœud dans l\'arbre pour afficher ses détails et effectuer des opérations (Créer enfant, Modifier, Dupliquer, Supprimer).',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildNodeDetailsInspector(
                            _selectedNode!,
                            treeAsync.valueOrNull ?? const [],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNodeWidget(AcademicNode node, {required int level}) {
    final isSelected = _selectedNodeId == node.id;
    final typeColor = nodeTypeColors[node.nodeType] ?? AppTheme.textMuted;
    final effectiveColor = !node.isActive ? Colors.white24 : typeColor;

    return Container(
      margin: EdgeInsets.only(left: level * 22.0, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.accentBlue.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isSelected
                ? AppTheme.accentBlue
                : (level > 0 ? AppTheme.primaryBorder : Colors.transparent),
            width: isSelected ? 3 : 2,
          ),
        ),
      ),
      // Material transparent entre le Container coloré (sélection) et l'ExpansionTile (qui rend un
      // ListTile en interne) : sans lui, le ListTile peint son fond/ink splash sur ce Material,
      // mais le Container au-dessus a lui aussi une couleur — Flutter considère alors que ce fond
      // serait invisible et lève une assertion. Même correctif que la barre latérale.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key(node.id),
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.only(left: 10, right: 8),
            iconColor: AppTheme.textMuted,
            collapsedIconColor: AppTheme.textMuted,
            onExpansionChanged: (_) => setState(() {
              _selectedNodeId = node.id;
              _selectedNode = node;
            }),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                nodeTypeIcons[node.nodeType] ?? Icons.folder_rounded,
                color: effectiveColor,
                size: 17,
              ),
            ),
            title: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() {
                _selectedNodeId = node.id;
                _selectedNode = node;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: node.isActive ? Colors.white : Colors.white38,
                          decoration: node.isActive ? null : TextDecoration.lineThrough,
                          decorationColor: Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: effectiveColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        nodeTypeLabels[node.nodeType] ?? node.nodeType.name,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: effectiveColor,
                        ),
                      ),
                    ),
                    if (node.code != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Text(
                          node.code!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                    if (!node.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withValues(alpha: 0.15),
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
              ),
            ),
            trailing: node.children.isNotEmpty ? null : const SizedBox.shrink(),
            children: node.children
                .map((child) => _buildTreeNodeWidget(child, level: level + 1))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeDetailsInspector(AcademicNode node, List<AcademicNode> tree) {
    final service = ref.read(supabaseServiceProvider);
    final childTypes = childNodeTypeOptions[node.nodeType] ?? const <NodeType>[];
    final siblings = _findSiblingsGroup(tree, node.id) ?? const <AcademicNode>[];
    final indexInSiblings = siblings.indexWhere((n) => n.id == node.id);
    final canMoveUp = indexInSiblings > 0;
    final canMoveDown = indexInSiblings >= 0 && indexInSiblings < siblings.length - 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: (nodeTypeColors[node.nodeType] ?? Colors.white)
                    .withValues(alpha: 0.2),
                child: Icon(
                  nodeTypeIcons[node.nodeType] ?? Icons.folder_rounded,
                  color: nodeTypeColors[node.nodeType] ?? Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Type: ${nodeTypeLabels[node.nodeType] ?? node.nodeType.toString().split('.').last} • Code: ${node.code ?? "N/A"}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (siblings.length > 1)
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                      tooltip: 'Monter',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(2),
                      color: canMoveUp ? Colors.white70 : Colors.white24,
                      onPressed: canMoveUp ? () => _moveNode(siblings, indexInSiblings, -1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      tooltip: 'Descendre',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(2),
                      color: canMoveDown ? Colors.white70 : Colors.white24,
                      onPressed:
                          canMoveDown ? () => _moveNode(siblings, indexInSiblings, 1) : null,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          _buildInspectorDetailRow('Identifiant Unique :', node.id),
          _buildInspectorDetailRow(
            'Statut :',
            node.isActive ? 'Actif' : 'Archivé',
          ),
          _buildInspectorDetailRow(
            'Date de création :',
            node.createdAt.toLocal().toString().split('.').first,
          ),
          const SizedBox(height: 24),

          Text(
            'Opérations sur ce Nœud',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (childTypes.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                  ),
                  onPressed: () => _showAddNodeModal(
                    context,
                    parentNode: node,
                    nodeTypeOptions: childTypes,
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Ajouter un élément'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.primaryBorder),
                ),
                onPressed: () => _showEditNodeModal(context, node),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.primaryBorder),
                ),
                onPressed: () => _duplicateNode(context, node),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Dupliquer l\'Arbre'),
              ),
              if (node.isActive)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentAmber,
                    side: const BorderSide(color: AppTheme.accentAmber),
                  ),
                  onPressed: () => _showDeactivateConfirmation(context, node, service),
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
                  ),
                  onPressed: () => _showReactivateConfirmation(context, node, service),
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
                  ),
                  onPressed: () => _showPermanentDeleteConfirmation(context, node, service),
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
          if (!node.isActive) ...[
            const SizedBox(height: 12),
            Text(
              'Nœud archivé : masqué aux élèves. Désarchivez-le pour le restaurer (lui et ses '
              'descendants), ou supprimez-le définitivement (irréversible, refusé si des élèves y '
              'sont encore rattachés).',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          if (childTypes.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Une Série est le niveau le plus fin de l\'arbre : elle ne peut pas avoir de sous-nœud.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  List<AcademicNode>? _findSiblingsGroup(List<AcademicNode> nodes, String targetId) {
    if (nodes.any((n) => n.id == targetId)) return nodes;
    for (final n in nodes) {
      final found = _findSiblingsGroup(n.children, targetId);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _moveNode(List<AcademicNode> siblings, int index, int direction) async {
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

  Widget _buildInspectorDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ),
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
    );
  }

  void _showAddNodeModal(
    BuildContext context, {
    required AcademicNode? parentNode,
    required List<NodeType> nodeTypeOptions,
  }) {
    assert(nodeTypeOptions.isNotEmpty, 'nodeTypeOptions ne doit jamais être vide ici');
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final parentNodeName = parentNode?.name ?? 'Racine';
    NodeType selectedNodeType = nodeTypeOptions.first;
    final parentId = parentNode?.id;
    final countryId = parentNode == null
        ? null
        : (parentNode.nodeType == NodeType.country ? parentNode.id : parentNode.countryId);
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: nodeTypeIcons[selectedNodeType] ?? Icons.add_circle_outline_rounded,
            iconColor: nodeTypeColors[selectedNodeType] ?? AppTheme.accentEmerald,
            text: 'Ajouter ${nodeTypeLabels[selectedNodeType] ?? selectedNodeType.name}',
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
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
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
                        helperText: 'Vous pouvez sauter des niveaux intermédiaires si besoin',
                        prefixIcon: Icon(Icons.account_tree_rounded, size: 20),
                      ),
                      items: nodeTypeOptions
                          .map((t) => DropdownMenuItem(value: t, child: Text(nodeTypeLabels[t] ?? t.name)))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedNodeType = v ?? selectedNodeType),
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
                      prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, size: 20),
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
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setModalState(() => fieldError = 'Le nom est obligatoire');
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        // La journalisation d'audit est automatique côté base (trigger
                        // audit_academic_nodes) — aucun appel applicatif nécessaire ici.
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
            child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, size: 20),
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
                    // Material transparent requis entre le Container coloré et le SwitchListTile
                    // (rend un ListTile en interne) — même correctif que l'arbre et la barre
                    // latérale : sinon assertion "background color may be invisible".
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        activeThumbColor: AppTheme.accentEmerald,
                        secondary: Icon(
                          isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          color: isActive ? AppTheme.accentEmerald : Colors.white38,
                          size: 20,
                        ),
                        title: Text(
                          'Nœud actif',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isActive ? 'Visible dans l\'application' : 'Masqué aux élèves',
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
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
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setModalState(() => fieldError = 'Le nom est obligatoire');
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
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
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentAmber),
                      ),
                      FutureBuilder<int>(
                        future: service.countProfilesForNode(node.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Text(
                              '• Calcul du nombre d\'élèves concernés...',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                            );
                          }
                          final count = snapshot.data!;
                          return Text(
                            count == 0
                                ? '• Aucun élève rattaché directement à ce nœud'
                                : '• $count élève(s) rattaché(s) directement à ce nœud seront masqués',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: count == 0 ? AppTheme.textMuted : AppTheme.accentAmber,
                              fontWeight: count == 0 ? FontWeight.normal : FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      Text(
                        '• Une entrée d\'audit sera enregistrée sous votre compte',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentAmber),
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
                        await service.deactivateNode(node.id, _currentAdminId());
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        if (mounted) {
                          setState(() {
                            _selectedNodeId = null;
                            _selectedNode = null;
                          });
                        }
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final nav = Navigator.of(context);
                      try {
                        await service.reactivateNode(node.id, _currentAdminId());
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'IRRÉVERSIBLE : ce nœud et tout son sous-arbre (${node.children.length} '
                      'enfant(s) direct(s)) seront physiquement supprimés de la base, avec tout leur '
                      'contenu rattaché (chapitres, exercices, examens...). Refusé automatiquement '
                      's\'il reste des élèves inscrits dessus.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tapez "${node.name}" pour confirmer :',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: node.name,
                      prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                    ),
                    onChanged: (v) => setModalState(() => nameMatches = v.trim() == node.name),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
              onPressed: (isLoading || !nameMatches)
                  ? null
                  : () async {
                      setModalState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      final nav = Navigator.of(context);
                      try {
                        await service.permanentlyDeleteNode(node.id, _currentAdminId());
                        ref.invalidate(academicTreeStreamProvider);
                        ref.invalidate(nodesByTypeProvider);
                        if (mounted) {
                          setState(() {
                            _selectedNodeId = null;
                            _selectedNode = null;
                          });
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        .where((n) => n.nodeType == NodeType.classType || n.nodeType == NodeType.series)
        .toList()
      ..sort((a, b) => _nodePath(a, byId).compareTo(_nodePath(b, byId)));

    if (mergeable.length < 2) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Les élèves, rattachements matière, chapitres, exercices, paliers, examens, '
                      'communautés et documents de la classe SOURCE seront transférés vers la classe '
                      'CIBLE. La classe source sera ensuite archivée (pas supprimée). Action '
                      'réservée aux deux nœuds de même type (Classe avec Classe, ou Série avec '
                      'Série). Pour partager du contenu SANS fusionner ni archiver de classe, '
                      'utilisez plutôt "Jumeler des Classes".',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
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
                      prefixIcon: Icon(Icons.remove_circle_outline_rounded, color: AppTheme.accentRose, size: 20),
                    ),
                    items: mergeable
                        .map((n) => DropdownMenuItem(
                              value: n.id,
                              child: Text(_nodePath(n, byId), overflow: TextOverflow.ellipsis),
                            ))
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
                      prefixIcon: Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentEmerald, size: 20),
                    ),
                    items: mergeable
                        .map((n) => DropdownMenuItem(
                              value: n.id,
                              child: Text(_nodePath(n, byId), overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => targetId = v),
                  ),
                  if (sourceId != null) ...[
                    const SizedBox(height: 16),
                    Text('Impact sur la classe SOURCE :',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Consumer(
                      builder: (context, ref, _) {
                        final impactAsync = ref.watch(classNodeMergeImpactProvider(sourceId!));
                        return impactAsync.when(
                          data: (rows) {
                            final nonZero = rows.where((r) => r.rowCount > 0).toList();
                            if (nonZero.isEmpty) {
                              return Text('Aucune donnée rattachée à cette classe.',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted));
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: nonZero
                                  .map((r) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentAmber.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('${r.entityLabel} : ${r.rowCount}',
                                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentAmber)),
                                      ))
                                  .toList(),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose, fontSize: 11)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (sourceId == null || targetId == null) {
                        setModalState(() => errorText = 'Sélectionnez les deux classes.');
                        return;
                      }
                      if (sourceId == targetId) {
                        setModalState(() => errorText = 'La source et la cible doivent être différentes.');
                        return;
                      }
                      if (byId[sourceId]!.nodeType != byId[targetId]!.nodeType) {
                        setModalState(() => errorText = 'Les deux nœuds doivent être du même type.');
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirmer la Fusion'),
            ),
          ],
        ),
      ),
    );
  }

  /// Gestion des groupes de classes jumelées (migration 19) — relation réelle et persistée,
  /// distincte de la fusion : aucune classe archivée, juste "ces classes partagent le programme"
  /// et peuvent se propager du contenu entre elles depuis Chapitres & Leçons.
  void _showTwinGroupsModal(BuildContext context, List<AcademicNode> tree) {
    final byId = _flattenById(tree);
    final candidates = byId.values
        .where((n) => n.nodeType == NodeType.classType || n.nodeType == NodeType.series)
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Déclarer que plusieurs classes/séries partagent le même programme, sans les '
                      'fusionner ni en archiver aucune. Une fois jumelées, dupliquer un chapitre '
                      'vers "toutes les classes jumelées" devient possible en un clic depuis '
                      'Chapitres & Leçons.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Groupes existants', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final groupsAsync = ref.watch(twinGroupsProvider);
                      return groupsAsync.when(
                        data: (groups) {
                          if (groups.isEmpty) {
                            return Text('Aucun groupe déclaré pour le moment.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted));
                          }
                          return Column(
                            children: groups
                                .map((g) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
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
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      g.label?.isNotEmpty == true ? g.label! : 'Groupe sans nom',
                                                      style: GoogleFonts.inter(
                                                          fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
                                                    ),
                                                    if (g.subjectName != null)
                                                      Text(
                                                        'Matière : ${g.subjectName}',
                                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: isLoading
                                                    ? null
                                                    : () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (c) => AlertDialog(
                                                            backgroundColor: AppTheme.primarySurface,
                                                            title: AppDialogTitle(
                                                              icon: Icons.link_off_rounded,
                                                              iconColor: AppTheme.accentRose,
                                                              text: 'Dissoudre ce groupe ?',
                                                              onClose: () => Navigator.pop(c, false),
                                                            ),
                                                            content: Text(
                                                              'Les classes ne seront plus considérées comme jumelées. Aucune donnée existante n\'est supprimée.',
                                                              style: GoogleFonts.inter(color: Colors.white70),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () => Navigator.pop(c, false),
                                                                  child: const Text('Annuler')),
                                                              ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
                                                                  onPressed: () => Navigator.pop(c, true),
                                                                  child: const Text('Dissoudre')),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm != true) return;
                                                        final service = ref.read(supabaseServiceProvider);
                                                        await service.dissolveClassTwinGroup(g.id, _currentAdminId());
                                                        ref.invalidate(twinGroupsProvider);
                                                        ref.invalidate(twinGroupForClassProvider);
                                                      },
                                                icon: const Icon(Icons.link_off_rounded, size: 14, color: AppTheme.accentRose),
                                                label: Text('Dissoudre',
                                                    style: GoogleFonts.inter(color: AppTheme.accentRose, fontSize: 11)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: g.members
                                                .map((m) => Chip(
                                                      label: Text(m.className, style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                                                      backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.15),
                                                      visualDensity: VisualDensity.compact,
                                                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                                                      onDeleted: isLoading
                                                          ? null
                                                          : () async {
                                                              final service = ref.read(supabaseServiceProvider);
                                                              await service.removeClassFromTwinGroup(
                                                                  g.id, m.classNodeId, _currentAdminId());
                                                              ref.invalidate(twinGroupsProvider);
                                                              ref.invalidate(twinGroupForClassProvider);
                                                            },
                                                    ))
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose, fontSize: 12)),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.primaryBorder),
                  const SizedBox(height: 12),
                  Text('Déclarer un nouveau groupe', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Un jumelage porte toujours sur une matière précise — les mêmes classes peuvent '
                    'être jumelées en Maths sans l\'être en Français.',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(subjectsProvider((countryId: null, includeInactive: false)));
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
                            .map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedSubjectId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nom du groupe (optionnel, ex: Terminale C parallèles)'),
                  ),
                  const SizedBox(height: 8),
                  ...candidates.map((c) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: newGroupSelection.contains(c.id),
                        activeColor: AppTheme.accentCyan,
                        title: Text(_nodePath(c, byId), style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                        onChanged: (checked) => setModalState(() {
                          if (checked == true) {
                            newGroupSelection.add(c.id);
                          } else {
                            newGroupSelection.remove(c.id);
                          }
                        }),
                      )),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedSubjectId == null) {
                        setModalState(() => errorText = 'La matière concernée est obligatoire.');
                        return;
                      }
                      if (newGroupSelection.length < 2) {
                        setModalState(() => errorText = 'Sélectionnez au moins 2 classes/séries.');
                        return;
                      }
                      final types = newGroupSelection.map((id) => byId[id]!.nodeType).toSet();
                      if (types.length > 1) {
                        setModalState(() => errorText = 'Toutes les classes du groupe doivent être du même type.');
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
                          labelController.text.trim().isEmpty ? null : labelController.text.trim(),
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
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_link_rounded, size: 16),
              label: const Text('Créer le groupe'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'erreur réutilisable pour les formulaires de cette page : les messages d'exception
/// Postgrest peuvent être longs, donc affichés à part plutôt que dans un TextField.errorText
/// (pensé pour rester court et net) qui les tronquerait ou déformerait le champ.
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
