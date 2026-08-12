import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/data_providers.dart';

class AcademicTreeScreen extends ConsumerStatefulWidget {
  const AcademicTreeScreen({super.key});

  @override
  ConsumerState<AcademicTreeScreen> createState() => _AcademicTreeScreenState();
}

class _AcademicTreeScreenState extends ConsumerState<AcademicTreeScreen> {
  String? _selectedNodeId;
  AcademicNode? _selectedNode;

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(academicTreeStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                    onPressed: () => _showAddNodeModal(
                      context,
                      parentNodeName: 'Racine',
                      nodeType: 'country',
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter un Pays'),
                  ),
                  const SizedBox(width: 12),
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
                    onPressed: () => _showMergeClassesModal(context),
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: treeAsync.when(
                    data: (tree) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arborescence Académique',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
                                : ListView(
                                    children: tree
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
                    ),
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
                        : _buildNodeDetailsInspector(_selectedNode!),
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

    return Container(
      margin: EdgeInsets.only(left: level * 20.0, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.accentBlue.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.accentBlue : Colors.transparent,
        ),
      ),
      child: ExpansionTile(
        key: Key(node.id),
        initiallyExpanded: true,
        leading: Icon(
          nodeTypeIcons[node.nodeType] ?? Icons.folder_rounded,
          color: isSelected
              ? AppTheme.accentBlue
              : nodeTypeColors[node.nodeType] ?? Colors.white70,
          size: 20,
        ),
        title: Row(
          children: [
            Text(
              node.name,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            if (node.code != null)
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
        ),
        trailing: node.children.isNotEmpty ? null : const SizedBox.shrink(),
        children: node.children
            .map((child) => _buildTreeNodeWidget(child, level: level + 1))
            .toList(),
      ),
    );
  }

  Widget _buildNodeDetailsInspector(AcademicNode node) {
    final service = ref.read(supabaseServiceProvider);

    return Column(
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
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),

        _buildInspectorDetailRow('Identifiant Unique :', node.id),
        _buildInspectorDetailRow(
          'Statut :',
          node.isActive ? 'Actif' : 'Inactif',
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
              ),
              onPressed: () => _showAddNodeModal(
                context,
                parentNodeName: node.name,
                nodeType: _getChildNodeTypeString(node.nodeType),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: Text('Ajouter ${_getChildNodeLabelString(node.nodeType)}'),
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
              onPressed: () {},
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Dupliquer l\'Arbre'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRose,
                side: const BorderSide(color: AppTheme.accentRose),
              ),
              onPressed: () => _showDeleteConfirmation(context, node, service),
              icon: const Icon(
                Icons.delete_forever_rounded,
                size: 16,
                color: AppTheme.accentRose,
              ),
              label: const Text('Supprimer Définitivement'),
            ),
          ],
        ),
      ],
    );
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

  String _getChildNodeTypeString(NodeType parentType) {
    switch (parentType) {
      case NodeType.country:
        return 'section';
      case NodeType.section:
        return 'education_type';
      case NodeType.educationType:
        return 'class';
      case NodeType.classType:
        return 'series';
      case NodeType.series:
        return 'series';
    }
  }

  String _getChildNodeLabelString(NodeType parentType) {
    switch (parentType) {
      case NodeType.country:
        return 'une Section';
      case NodeType.section:
        return 'un Type d\'Enseignement';
      case NodeType.educationType:
        return 'une Classe';
      case NodeType.classType:
        return 'une Série';
      case NodeType.series:
        return 'un Sous-nœud';
    }
  }

  void _showAddNodeModal(
    BuildContext context, {
    required String parentNodeName,
    required String nodeType,
  }) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Ajouter $nodeType sous "$parentNodeName"',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'entité (ex: Classe de 3ème)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code court (ex: 3E)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(supabaseServiceProvider);
              await service.createNode(
                name: nameController.text,
                nodeType: nodeType,
                code: codeController.text,
                displayOrder: 0,
              );
              ref.invalidate(academicTreeStreamProvider);
              Navigator.pop(context);
            },
            child: const Text('Créer l\'élément'),
          ),
        ],
      ),
    );
  }

  void _showEditNodeModal(BuildContext context, AcademicNode node) {
    final nameController = TextEditingController(text: node.name);
    final codeController = TextEditingController(text: node.code ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Modifier "${node.name}"',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom de l\'entité'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Code court'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(supabaseServiceProvider);
              await service.updateNode(
                node.id,
                name: nameController.text,
                code: codeController.text,
              );
              ref.invalidate(academicTreeStreamProvider);
              Navigator.pop(context);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AcademicNode node,
    SupabaseService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Supprimer "${node.name}" ?',
          style: GoogleFonts.outfit(color: AppTheme.accentRose),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attention ! Cette action est irréversible. Vérification des dépendances avant suppression :',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accentRose.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${node.children.length} nœuds enfants rattachés',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.accentRose,
                    ),
                  ),
                  Text(
                    '• Les données associées seront désactivées',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.accentRose,
                    ),
                  ),
                  Text(
                    '• Un audit log sera généré',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.accentRose,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
            ),
            onPressed: () async {
              await service.deleteNode(node.id);
              ref.invalidate(academicTreeStreamProvider);
              Navigator.pop(context);
            },
            child: const Text('Supprimer avec intégrité'),
          ),
        ],
      ),
    );
  }

  void _showMergeClassesModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Fusionner deux Classes',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'La fusion permettra de regrouper tous les élèves, leçons et exercices de deux classes en une seule entité. Les profils des élèves seront automatiquement migrés.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentIndigo,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Confirmer la Fusion'),
          ),
        ],
      ),
    );
  }
}
