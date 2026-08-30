import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/widgets/app_dialog_title.dart';

/// Icônes proposées pour une fonctionnalité de la Matrice de Droits — un nom stable (icon_name,
/// stocké en base) plutôt que l'IconData lui-même, pour rester indépendant de la version de Flutter
/// et permettre à l'admin de choisir dans une liste courte plutôt que de taper un nom au hasard.
const Map<String, IconData> _matrixFeatureIcons = {
  'menu_book': Icons.menu_book_rounded,
  'quiz': Icons.quiz_rounded,
  'assignment_turned_in': Icons.assignment_turned_in_rounded,
  'school': Icons.school_rounded,
  'storefront': Icons.storefront_rounded,
  'groups': Icons.groups_rounded,
  'psychology': Icons.psychology_rounded,
  'emoji_events': Icons.emoji_events_rounded,
  'print': Icons.print_rounded,
  'forum': Icons.forum_rounded,
  'campaign': Icons.campaign_rounded,
  'lock': Icons.lock_rounded,
};

IconData _iconForName(String name) => _matrixFeatureIcons[name] ?? Icons.lock_rounded;

class AccessMatrixScreen extends ConsumerStatefulWidget {
  const AccessMatrixScreen({super.key});

  @override
  ConsumerState<AccessMatrixScreen> createState() => _AccessMatrixScreenState();
}

class _AccessMatrixScreenState extends ConsumerState<AccessMatrixScreen> {
  bool _isSaving = false;

  // In-memory matrix cache: Map<TierId, Map<FeatureKey, AccessMatrixEntry>>
  final Map<String, Map<String, AccessMatrixEntry>> _matrixCache = {};
  // Uniquement les cellules réellement modifiées via la modale — permet d'afficher un indicateur
  // "modifications non enregistrées" fiable et d'éviter de ré-écrire silencieusement des centaines
  // de cellules inchangées à chaque clic sur "Enregistrer".
  final Set<String> _dirtyKeys = {};

  @override
  Widget build(BuildContext context) {
    // Avant : tiersAsync ignorait totalement le pays sélectionné dans la navbar et chargeait TOUS
    // les paliers de TOUS les pays/classes dans une seule table à plat, sans même les étiqueter par
    // classe — impossible à distinguer si deux paliers de pays différents partagent un nom (ex:
    // "Gratuit"). On dérive maintenant du même sélecteur global que le reste de l'app.
    final scopedCountryIds = ref.watch(selectedCountryIdsProvider);
    final tiersAsync = ref.watch(subscriptionTiersProvider(null));
    // Avant : la liste des fonctionnalités était codée en dur côté Dart, sans aucun moyen pour
    // l'admin d'en ajouter/modifier/supprimer — maintenant pilotée par la table matrix_features.
    final featuresAsync = ref.watch(matrixFeaturesProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — Column plutôt que Row : un Wrap de plusieurs boutons comme simple frère d'un
          // Expanded ne rétrécit jamais (même bug que academic_tree_screen.dart, retour utilisateur
          // réel très insistant, 2026-08-30) — le Column(crossAxisAlignment.end) intermédiaire qui
          // enveloppait déjà le Wrap n'y changeait rien, un Column non contraint hérite du même
          // problème que le Wrap qu'il contient.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Matrice de Droits Dynamique (Access Matrix)',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // Vrai seulement pour les fonctionnalités marquées "Appliqué" ci-dessous — voir
                // le badge d'avertissement sur les lignes non encore appliquées.
                'Configuration des règles de restriction par palier (contrôle réellement l\'accès côté élève pour les fonctionnalités marquées "Appliqué")',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              // Wrap plutôt que Row : deux boutons au libellé long côte à côte débordaient hors de
              // l'écran ("RenderFlex overflowed").
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.primaryBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () => _showCreateOrEditFeatureDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 18, color: AppTheme.accentCyan),
                        label: const Text('Ajouter une Fonctionnalité'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: (_isSaving || _dirtyKeys.isEmpty) ? null : () => _saveAllChanges(context),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Enregistrer la Matrice'),
                      ),
                    ],
                  ),
              if (_dirtyKeys.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${_dirtyKeys.length} modification(s) non enregistrée(s)',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentAmber, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Main View Body
          Expanded(
            child: featuresAsync.when(
              data: (features) => tiersAsync.when(
                data: (allTiers) {
                  final tiers = scopedCountryIds == null
                      ? allTiers
                      : allTiers.where((t) => scopedCountryIds.contains(t.countryId)).toList();
                  if (tiers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.layers_clear_rounded, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            scopedCountryIds == null
                                ? 'Aucun palier d\'abonnement configuré.'
                                : 'Aucun palier configuré pour le(s) pays sélectionné(s) dans la navbar.',
                            style: GoogleFonts.inter(color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  if (features.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rule_folder_rounded, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune fonctionnalité définie. Cliquez sur "Ajouter une Fonctionnalité".',
                            style: GoogleFonts.inter(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildMatrixTable(tiers, features);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Erreur de chargement: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur de chargement: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTable(List<SubscriptionTier> tiers, List<MatrixFeature> features) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.primaryDark),
              dataRowMinHeight: 65,
              dataRowMaxHeight: 75,
              columns: [
                DataColumn(
                  label: Text(
                    'Fonctionnalité / Contenu',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                ...tiers.map(
                  (tier) => DataColumn(
                    label: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.name.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentBlue,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          tier.price == 0 ? 'Gratuit' : '${tier.price.toStringAsFixed(0)} FCFA / ${tier.durationDays}j',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        // Plusieurs paliers de classes/pays différents peuvent partager le même nom
                        // (ex: "Gratuit") — sans cette étiquette, impossible de les distinguer dans
                        // la matrice.
                        FutureBuilder<AcademicNode?>(
                          future: ref.read(supabaseServiceProvider).getNode(tier.classNodeId),
                          builder: (context, snapshot) => Text(
                            snapshot.data?.name ?? '…',
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              rows: features.map((feature) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Icon(_iconForName(feature.iconName), size: 18, color: AppTheme.accentCyan),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              feature.label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (!feature.isEnforced) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Pas encore appliqué techniquement : modifier ce réglage ici '
                                  'n\'a aucun effet côté élève pour le moment.',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 11, color: AppTheme.accentAmber),
                                    const SizedBox(width: 3),
                                    Text('Non appliqué',
                                        style: GoogleFonts.inter(
                                            fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentAmber)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
                            tooltip: 'Modifier cette fonctionnalité',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => _showCreateOrEditFeatureDialog(context, existing: feature),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, size: 14, color: AppTheme.accentRose),
                            tooltip: 'Supprimer cette fonctionnalité',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => _showDeleteFeatureConfirmation(context, feature),
                          ),
                        ],
                      ),
                    ),
                    ...tiers.map((tier) {
                      return DataCell(
                        Consumer(
                          builder: (context, ref, _) {
                            final matrixAsync = ref.watch(accessMatrixProvider(tier.id));

                            return matrixAsync.when(
                              data: (entries) {
                                final freshEntry = entries.firstWhere(
                                  (e) => e.featureKey == feature.featureKey,
                                  orElse: () => AccessMatrixEntry(
                                    id: 'temp_${tier.id}_${feature.featureKey}',
                                    tierId: tier.id,
                                    featureKey: feature.featureKey,
                                    accessLevel: 'aucun',
                                    limitParameter: {},
                                  ),
                                );

                                // BUG CRITIQUE corrigé : cette ligne faisait `[...] = entry` (écrasement
                                // inconditionnel) au lieu de `.putIfAbsent`. Comme accessMatrixProvider
                                // n'est invalidé qu'après "Enregistrer la Matrice", chaque rebuild déclenché
                                // par l'édition d'une AUTRE cellule (setState) re-lisait la valeur EN BASE
                                // (pas encore sauvegardée) et écrasait silencieusement l'édition locale en
                                // attente dans _matrixCache — "Accès complet" semblait n'avoir aucun effet.
                                _matrixCache.putIfAbsent(tier.id, () => {}).putIfAbsent(feature.featureKey, () => freshEntry);
                                final displayEntry = _matrixCache[tier.id]![feature.featureKey]!;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _editAccessModal(context, tier, feature, displayEntry),
                                  child: _buildBadge(displayEntry.accessLevel, displayEntry.limitParameter),
                                );
                              },
                              loading: () => const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (e, _) => Text('—', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String accessLevel, Map<String, dynamic> limits) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (accessLevel) {
      case 'complet':
        bg = AppTheme.accentEmerald.withValues(alpha: 0.15);
        fg = AppTheme.accentEmerald;
        icon = Icons.check_circle_rounded;
        label = 'Accès complet';
        break;
      case 'limite':
        bg = AppTheme.accentAmber.withValues(alpha: 0.15);
        fg = AppTheme.accentAmber;
        icon = Icons.tune_rounded;
        final detail = limits.isNotEmpty ? ' (${limits.values.first})' : '';
        label = 'Limité$detail';
        break;
      default:
        bg = Colors.white.withValues(alpha: 0.05);
        fg = Colors.white38;
        icon = Icons.block_rounded;
        label = 'Aucun (Flouté)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  void _editAccessModal(
    BuildContext context,
    SubscriptionTier tier,
    MatrixFeature feature,
    AccessMatrixEntry currentEntry,
  ) {
    String selectedLevel = currentEntry.accessLevel;
    final limitController = TextEditingController(
      text: currentEntry.limitParameter.values.firstOrNull?.toString() ?? '3',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: _iconForName(feature.iconName),
            text: 'Règle d\'accès : ${feature.label}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Palier : ${tier.name.toUpperCase()} (${tier.price} FCFA)',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.accentBlue),
                ),
                if (!feature.isEnforced) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Ce réglage sera enregistré mais n\'a aucun effet technique côté élève pour '
                      'le moment (fonctionnalité pas encore appliquée en base).',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentAmber, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  value: 'complet',
                  // ignore: deprecated_member_use
                  groupValue: selectedLevel,
                  activeColor: AppTheme.accentEmerald,
                  title: Text('Accès complet', style: GoogleFonts.inter(color: Colors.white)),
                  subtitle: Text('Aucune restriction ni floutage', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                  // ignore: deprecated_member_use
                  onChanged: (v) => setModalState(() => selectedLevel = v!),
                ),
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  value: 'limite',
                  // ignore: deprecated_member_use
                  groupValue: selectedLevel,
                  activeColor: AppTheme.accentAmber,
                  title: Text('Accès limité', style: GoogleFonts.inter(color: Colors.white)),
                  subtitle: Text('Floutage après épuisement du quota', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                  // ignore: deprecated_member_use
                  onChanged: (v) => setModalState(() => selectedLevel = v!),
                ),
                if (selectedLevel == 'limite') ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 16, top: 4, bottom: 8),
                    child: TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Valeur du quota (ex: 3 chapitres ou 5 questions/jour)',
                        filled: true,
                        fillColor: AppTheme.primaryDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
                // ignore: deprecated_member_use
                RadioListTile<String>(
                  value: 'aucun',
                  // ignore: deprecated_member_use
                  groupValue: selectedLevel,
                  activeColor: AppTheme.accentRose,
                  title: Text('Aucun accès (Flouté 100%)', style: GoogleFonts.inter(color: Colors.white)),
                  subtitle: Text('Incitation systématique au paiement', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                  // ignore: deprecated_member_use
                  onChanged: (v) => setModalState(() => selectedLevel = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: () {
                final limitVal = int.tryParse(limitController.text.trim()) ?? 3;
                final limitMap = selectedLevel == 'limite'
                    ? {'limit_value': limitVal}
                    : <String, dynamic>{};

                final updatedEntry = AccessMatrixEntry(
                  id: currentEntry.id,
                  tierId: tier.id,
                  featureKey: feature.featureKey,
                  accessLevel: selectedLevel,
                  limitParameter: limitMap,
                );

                setState(() {
                  _matrixCache.putIfAbsent(tier.id, () => {})[feature.featureKey] = updatedEntry;
                  _dirtyKeys.add('${tier.id}::${feature.featureKey}');
                });

                Navigator.pop(ctx);
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAllChanges(BuildContext context) async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      // Uniquement les cellules effectivement éditées (_dirtyKeys) — auparavant, TOUT le contenu
      // de _matrixCache était ré-écrit à chaque sauvegarde (des centaines de lignes inchangées à
      // chaque clic), ce qui rendait aussi impossible de savoir s'il y avait quoi que ce soit à
      // enregistrer.
      final touchedTierIds = <String>{};
      final savedKeys = <String>[];
      for (final dirtyKey in _dirtyKeys) {
        final parts = dirtyKey.split('::');
        final tierId = parts[0];
        final featureKey = parts[1];
        final entry = _matrixCache[tierId]?[featureKey];
        if (entry == null) continue;
        await service.upsertAccessMatrixEntry(
          tierId: tierId,
          featureKey: entry.featureKey,
          accessLevel: entry.accessLevel,
          limitParameter: entry.limitParameter,
        );
        touchedTierIds.add(tierId);
        savedKeys.add(dirtyKey);
      }
      // Retire du cache local les entrées qu'on vient de sauvegarder : elles seront ré-alimentées
      // avec l'id réel (plus le "temp_...") au prochain build, depuis le provider fraîchement
      // invalidé ci-dessous.
      for (final key in savedKeys) {
        final parts = key.split('::');
        _matrixCache[parts[0]]?.remove(parts[1]);
      }
      for (final tierId in touchedTierIds) {
        ref.invalidate(accessMatrixProvider(tierId));
      }
      setState(() => _dirtyKeys.clear());

      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentEmerald,
            content: Text(
              'Matrice de droits synchronisée avec succès dans Supabase !',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text('Erreur d\'enregistrement: $e', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Avant, la liste des fonctionnalités était figée dans le code Dart — aucun moyen d'en ajouter
  /// une nouvelle depuis l'admin sans une mise à jour de l'application elle-même.
  void _showCreateOrEditFeatureDialog(BuildContext context, {MatrixFeature? existing}) {
    final isEditing = existing != null;
    final keyController = TextEditingController(text: existing?.featureKey ?? '');
    final labelController = TextEditingController(text: existing?.label ?? '');
    String selectedIcon = existing?.iconName ?? 'lock';
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
            icon: _iconForName(selectedIcon),
            text: isEditing ? 'Modifier "${existing.label}"' : 'Ajouter une Fonctionnalité',
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
                    controller: labelController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nom affiché (ex: Cours Particuliers Réservés)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: keyController,
                    enabled: !isEditing,
                    style: TextStyle(color: isEditing ? AppTheme.textMuted : Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Clé technique (ex: premium_courses, minuscules et underscores)',
                      helperText: isEditing
                          ? 'Non modifiable après création (référencée par la sécurité de la base).'
                          : 'Doit correspondre à une clé vérifiée côté base pour avoir un effet réel.',
                      helperMaxLines: 2,
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Icône', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _matrixFeatureIcons.entries.map((e) {
                      final isSelected = selectedIcon == e.key;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setModalState(() => selectedIcon = e.key),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accentCyan.withValues(alpha: 0.2) : AppTheme.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppTheme.accentCyan : AppTheme.primaryBorder),
                          ),
                          child: Icon(e.value, size: 20, color: isSelected ? AppTheme.accentCyan : Colors.white70),
                        ),
                      );
                    }).toList(),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Une nouvelle clé n\'a d\'effet réel que si elle correspond à une vérification '
                        'ajoutée côté base — sinon elle apparaîtra ici marquée "Non appliqué".',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentAmber, height: 1.4),
                      ),
                    ),
                  ],
                  if (submitError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final label = labelController.text.trim();
                      final key = keyController.text.trim();
                      if (label.isEmpty) {
                        setModalState(() => fieldError = 'Le nom affiché est obligatoire');
                        return;
                      }
                      if (!isEditing) {
                        if (key.isEmpty) {
                          setModalState(() => fieldError = 'La clé technique est obligatoire');
                          return;
                        }
                        if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
                          setModalState(() =>
                              fieldError = 'Minuscules, chiffres et underscores uniquement (doit commencer par une lettre)');
                          return;
                        }
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        if (isEditing) {
                          await service.updateMatrixFeature(existing.id, label: label, iconName: selectedIcon);
                        } else {
                          await service.createMatrixFeature(
                            featureKey: key,
                            label: label,
                            iconName: selectedIcon,
                          );
                        }
                        ref.invalidate(matrixFeaturesProvider);
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
                  : Text(isEditing ? 'Enregistrer' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteFeatureConfirmation(BuildContext context, MatrixFeature feature) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.accentRose,
            text: 'Supprimer "${feature.label}" ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Text(
              'IRRÉVERSIBLE : toutes les règles d\'accès configurées pour cette fonctionnalité, sur '
              'tous les paliers, seront également supprimées.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.deleteMatrixFeature(feature.id, feature.featureKey);
                        _matrixCache.forEach((_, features) => features.remove(feature.featureKey));
                        _dirtyKeys.removeWhere((k) => k.endsWith('::${feature.featureKey}'));
                        ref.invalidate(matrixFeaturesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Fonctionnalité "${feature.label}" supprimée.'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        messenger.showSnackBar(
                          SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }
}
