import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/academic_node.dart';
import '../models/enums.dart';
import '../providers/data_providers.dart';
import '../theme/app_theme.dart';

/// Sélecteur de classe en cascade, un champ par niveau réel de l'Arbre académique — jamais une
/// seule liste plate mélangeant toutes les classes de tous les sous-systèmes (retour utilisateur
/// explicite). Générique : ne code en dur aucun pays ni aucune profondeur. À chaque niveau, le
/// champ n'affiche QUE les enfants du niveau choisi juste au-dessus ; changer un niveau réinitialise
/// immédiatement tous les niveaux en dessous. Le libellé de chaque champ vient du `node_type` réel
/// des options qu'il propose (Sous-système, Type d'Enseignement, Cycle, Classe, Famille, Série,
/// Spécialité — voir `nodeTypeLabels`), pas d'un schéma fixe "Cameroun -> Francophone -> ...".
///
/// [onLeafSelected] n'est appelé qu'avec un id non nul quand la sélection atteint un nœud qui n'a
/// lui-même plus d'enfant (la vraie "classe" au sens du cahier, qu'il s'agisse d'une classe, d'une
/// série ou d'une spécialité) ; il est rappelé avec `null` dès que le chemin redevient incomplet.
class AcademicPathSelector extends ConsumerStatefulWidget {
  final String? selectedNodeId;
  final ValueChanged<String?> onLeafSelected;

  const AcademicPathSelector({
    super.key,
    required this.selectedNodeId,
    required this.onLeafSelected,
  });

  @override
  ConsumerState<AcademicPathSelector> createState() => _AcademicPathSelectorState();
}

class _AcademicPathSelectorState extends ConsumerState<AcademicPathSelector> {
  List<AcademicNode> _path = const [];

  /// N'intervient que lorsque le parent impose une sélection EXTERNE différente de la feuille
  /// actuelle (chargement initial d'une classe déjà choisie, ou changement programmatique) — un
  /// `selectedNodeId` nul ne doit jamais effacer une navigation interne en cours : tant qu'aucune
  /// feuille n'est atteinte, le parent n'a justement rien à rapporter (onLeafSelected(null)), ce qui
  /// ne veut pas dire "recommencer à zéro".
  void _syncFromSelection(Map<String, AcademicNode> byId) {
    final external = widget.selectedNodeId;
    if (external == null) return;
    final currentLeaf = _path.isNotEmpty ? _path.last.id : null;
    if (external == currentLeaf) return;
    final chain = <AcademicNode>[];
    AcademicNode? current = byId[external];
    while (current != null) {
      chain.insert(0, current);
      current = current.parentId != null ? byId[current.parentId] : null;
    }
    _path = chain;
  }

  void _selectAt(int depth, AcademicNode? node) {
    setState(() {
      _path = [..._path.sublist(0, depth), ?node];
    });
    widget.onLeafSelected(node != null && node.children.isEmpty ? node.id : null);
  }

  void _truncateTo(int keepCount) {
    setState(() => _path = _path.sublist(0, keepCount));
    final last = _path.isEmpty ? null : _path.last;
    widget.onLeafSelected(last != null && last.children.isEmpty ? last.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(academicTreeStreamProvider(false));
    final selectedCountryIds = ref.watch(selectedCountryIdsProvider);

    return treeAsync.when(
      loading: () => const _SelectorSkeleton(),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.accentRose.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
        ),
        child: Text('Impossible de charger l\'arbre académique : $e',
            style: GoogleFonts.inter(color: AppTheme.accentRose, fontSize: 12.5)),
      ),
      data: (fullTree) {
        final tree = selectedCountryIds == null
            ? fullTree
            : fullTree.where((c) => selectedCountryIds.contains(c.id)).toList();
        if (tree.isEmpty) {
          return Text(
            'Aucun pays configuré dans l\'Arbre académique.',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          );
        }
        final byId = <String, AcademicNode>{};
        void index(List<AcademicNode> nodes) {
          for (final n in nodes) {
            byId[n.id] = n;
            index(n.children);
          }
        }

        index(tree);
        _syncFromSelection(byId);

        final levels = <List<AcademicNode>>[tree];
        for (final node in _path) {
          if (node.children.isEmpty) break;
          levels.add(node.children);
        }
        final allLeaves = byId.values.where((n) => n.children.isEmpty).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchShortcut(
              allLeaves: allLeaves,
              byId: byId,
              onPicked: (node) {
                final chain = <AcademicNode>[];
                AcademicNode? cur = node;
                while (cur != null) {
                  chain.insert(0, cur);
                  cur = cur.parentId != null ? byId[cur.parentId] : null;
                }
                setState(() => _path = chain);
                widget.onLeafSelected(node.id);
              },
            ),
            if (_path.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Breadcrumb(path: _path, onTapCrumb: _truncateTo),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int depth = 0; depth < levels.length; depth++)
                  SizedBox(
                    width: 220,
                    child: _LevelDropdown(
                      options: levels[depth],
                      selectedId: depth < _path.length ? _path[depth].id : null,
                      onChanged: (node) => _selectAt(depth, node),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  final List<AcademicNode> options;
  final String? selectedId;
  final ValueChanged<AcademicNode?> onChanged;

  const _LevelDropdown({
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    // Ordre d'affichage réel de l'arbre (display_order), jamais alphabétique — sinon "Première A"
    // se retrouverait avant "Troisième" simplement parce que P précède T.
    final sorted = [...options]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final label = nodeTypeLabels[sorted.first.nodeType] ?? 'Niveau';
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: selectedId,
      isExpanded: true,
      dropdownColor: AppTheme.primarySurface,
      style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppTheme.primaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryBorder),
        ),
      ),
      hint: const Text('Sélectionner…', style: TextStyle(color: AppTheme.textMuted)),
      items: sorted
          .map((n) => DropdownMenuItem(value: n.id, child: Text(n.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (id) => onChanged(id == null ? null : sorted.firstWhere((n) => n.id == id)),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final List<AcademicNode> path;
  final ValueChanged<int> onTapCrumb;

  const _Breadcrumb({required this.path, required this.onTapCrumb});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < path.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.textMuted),
            ),
          InkWell(
            onTap: () => onTapCrumb(i + 1),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                path[i].name,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: i == path.length - 1 ? Colors.white : AppTheme.accentCyan,
                  fontWeight: i == path.length - 1 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchShortcut extends StatelessWidget {
  final List<AcademicNode> allLeaves;
  final Map<String, AcademicNode> byId;
  final ValueChanged<AcademicNode> onPicked;

  const _SearchShortcut({
    required this.allLeaves,
    required this.byId,
    required this.onPicked,
  });

  /// Chemin complet (hors racine Pays) pour désambiguïser deux options qui porteraient le même nom
  /// combiné dans des branches différentes — la liste de résultats a besoin de plus de contexte que
  /// le champ de texte une fois la sélection faite.
  String _fullPath(AcademicNode n) {
    final segments = <String>[];
    AcademicNode? cur = n;
    while (cur != null) {
      segments.insert(0, cur.name);
      cur = cur.parentId != null ? byId[cur.parentId] : null;
    }
    return segments.length > 1 ? segments.sublist(1).join(' › ') : segments.join(' › ');
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AcademicNode>(
      displayStringForOption: (n) => describeNodeWithAncestorClass(n, byId),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<AcademicNode>.empty();
        return allLeaves.where((n) => _fullPath(n).toLowerCase().contains(q)).take(20);
      },
      onSelected: onPicked,
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          elevation: 6,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(4),
              children: options
                  .map((n) => ListTile(
                        dense: true,
                        title: Text(describeNodeWithAncestorClass(n, byId),
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(_fullPath(n),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        onTap: () => onSelected(n),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Rechercher une classe directement (ex: Terminale C, ESCOM, Form 4)…',
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12.5),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 18),
          isDense: true,
          filled: true,
          fillColor: AppTheme.primaryDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryBorder),
          ),
        ),
      ),
    );
  }
}

class _SelectorSkeleton extends StatelessWidget {
  const _SelectorSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) => Container(
          width: width,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [bar(220), bar(220), bar(220)],
    );
  }
}
