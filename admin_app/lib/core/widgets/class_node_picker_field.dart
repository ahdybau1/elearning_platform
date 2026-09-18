import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/academic_node.dart';
import '../providers/data_providers.dart';
import '../theme/app_theme.dart';
import 'app_dialog_title.dart';

/// Sélecteur de classe/série/spécialité par navigation progressive dans l'arbre complet
/// (Sous-système -> Type d'enseignement -> Cycle -> Classe -> Série/Famille -> Spécialité),
/// au lieu d'un menu déroulant plat qui mélangeait toutes les classes de tous les sous-systèmes
/// sans contexte (retour utilisateur explicite). Un niveau qui n'a qu'une seule option est
/// traversé automatiquement (§20 : jamais montrer l'arbre entier, sauter les niveaux inutiles).
///
/// Remplace, écran par écran, le pattern `mergeClassOptions(...)` + `DropdownButtonFormField` —
/// remplacement direct : mêmes `selectedId`/`onChanged`, plus besoin de charger et fusionner
/// `nodesByTypeProvider('class')`/`nodesByTypeProvider('series')` séparément dans chaque écran.
const _clearSelectionSentinel = '__pq_learn_clear_selection__';

class ClassNodePickerField extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String label;

  /// Quand renseigné, affiche cette option en permanence en haut de la boîte de dialogue,
  /// permettant de revenir à "pas de filtre" sans devoir choisir une classe précise
  /// (ex: "Toutes les classes" pour une annonce qui cible tout le monde).
  final String? clearOptionLabel;

  /// Désactive le champ (ex: pays pas encore résolu sans ambiguïté) — le sélecteur reste visible
  /// mais ne s'ouvre plus, plutôt que de laisser ouvrir la navigation pour ne rien faire au clic.
  final bool enabled;

  const ClassNodePickerField({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.label = 'Classe / Série',
    this.clearOptionLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(academicTreeStreamProvider(false));
    // Respecte le filtre pays global de la navbar (jamais redemander le pays dans un formulaire —
    // convention déjà établie ailleurs via selectedCountryIdsProvider) : null = tous les pays.
    final selectedCountryIds = ref.watch(selectedCountryIdsProvider);
    return treeAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur : $e', style: const TextStyle(color: AppTheme.accentRose)),
      data: (fullTree) {
        final tree = selectedCountryIds == null
            ? fullTree
            : fullTree.where((c) => selectedCountryIds.contains(c.id)).toList();
        final byId = <String, AcademicNode>{};
        void index(List<AcademicNode> nodes) {
          for (final n in nodes) {
            byId[n.id] = n;
            index(n.children);
          }
        }

        index(tree);
        final selectedNode = selectedId != null ? byId[selectedId] : null;
        final displayLabel = selectedNode != null
            ? describeNodeWithAncestorClass(selectedNode, byId)
            : (selectedId == null ? clearOptionLabel : null);

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: !enabled || tree.isEmpty
              ? null
              : () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) => _CascadingNodeDialog(
                      root: tree,
                      byId: byId,
                      clearOptionLabel: clearOptionLabel,
                    ),
                  );
                  if (result == null) return;
                  onChanged(result == _clearSelectionSentinel ? null : result);
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            ),
            child: Text(
              displayLabel ?? 'Sélectionner…',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: displayLabel != null ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CascadingNodeDialog extends StatefulWidget {
  final List<AcademicNode> root;
  final Map<String, AcademicNode> byId;
  final String? clearOptionLabel;

  const _CascadingNodeDialog({
    required this.root,
    required this.byId,
    this.clearOptionLabel,
  });

  @override
  State<_CascadingNodeDialog> createState() => _CascadingNodeDialogState();
}

class _CascadingNodeDialogState extends State<_CascadingNodeDialog> {
  late List<AcademicNode> _path;

  @override
  void initState() {
    super.initState();
    _path = [];
    _autoSkipSingletons();
  }

  List<AcademicNode> get _currentChildren =>
      _path.isEmpty ? widget.root : _path.last.children;

  /// Traverse automatiquement tout niveau qui n'a qu'un seul enfant lui-même non terminal — un
  /// seul pays actif, une seule section, etc. ne doivent pas exiger un clic (§20).
  void _autoSkipSingletons() {
    while (_currentChildren.length == 1 && _currentChildren.first.children.isNotEmpty) {
      _path = [..._path, _currentChildren.first];
    }
  }

  void _goInto(AcademicNode node) {
    setState(() {
      _path = [..._path, node];
      _autoSkipSingletons();
    });
  }

  void _goBack() {
    setState(() => _path = _path.sublist(0, _path.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final children = _currentChildren;
    final parentForLabel = _path.isEmpty ? null : _path.last;

    return AlertDialog(
      backgroundColor: AppTheme.primarySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: AppDialogTitle(
        icon: Icons.account_tree_rounded,
        iconColor: AppTheme.accentCyan,
        text: _path.isEmpty ? 'Choisir une classe' : _path.map((n) => n.name).join(' > '),
        onClose: () => Navigator.pop(context),
      ),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_path.isNotEmpty)
              TextButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Précédent'),
              ),
            if (widget.clearOptionLabel != null) ...[
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.primaryBorder),
                ),
                leading: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                title: Text(widget.clearOptionLabel!, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, _clearSelectionSentinel),
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: children.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune sous-catégorie ici.',
                        style: GoogleFonts.inter(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: children.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final node = children[i];
                        final isLeaf = node.children.isEmpty;
                        final label = isLeaf && parentForLabel != null
                            ? describeNodeWithAncestorClass(node, widget.byId)
                            : node.name;
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppTheme.primaryBorder),
                          ),
                          title: Text(label, style: const TextStyle(color: Colors.white)),
                          trailing: Icon(
                            isLeaf ? Icons.check_rounded : Icons.chevron_right_rounded,
                            color: isLeaf ? AppTheme.accentEmerald : AppTheme.textMuted,
                            size: 18,
                          ),
                          onTap: () =>
                              isLeaf ? Navigator.pop(context, node.id) : _goInto(node),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      ],
    );
  }
}
