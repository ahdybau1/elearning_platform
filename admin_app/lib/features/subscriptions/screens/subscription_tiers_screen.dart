import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/academic_node.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class SubscriptionTiersScreen extends ConsumerStatefulWidget {
  const SubscriptionTiersScreen({super.key});

  @override
  ConsumerState<SubscriptionTiersScreen> createState() =>
      _SubscriptionTiersScreenState();
}

class _SubscriptionTiersScreenState
    extends ConsumerState<SubscriptionTiersScreen> {
  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(subscriptionTiersProvider(null));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column plutôt que Row(Expanded(titre), bouton) : le bouton au libellé long
          // ("Nouveau Palier Tarifaire") comme simple frère de l'Expanded affamait quand même le
          // titre sur mobile (retour utilisateur réel, capture d'écran, 2026-08-30 — le premier
          // correctif avec Expanded seul ne suffisait pas, même bug que les autres écrans).
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paliers d\'Abonnement & Grille Tarifaire',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Configuration des tarifs par classe et par durée',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _showEditTierModal(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouveau Palier Tarifaire'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: tiersAsync.when(
              data: (tiers) {
                if (tiers.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun palier tarifaire configuré. Cliquez sur "Nouveau Palier Tarifaire" pour créer le premier.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                // crossAxisCount fixé à 3 sans seuil mobile : sur téléphone chaque carte
                // n'avait plus que ~110px de large pour ~77px de haut (aspectRatio 1.4 conservé),
                // largement insuffisant pour son contenu (titre, prix, durée, classe, bouton) —
                // le texte débordait et chevauchait visuellement la carte suivante (retour
                // utilisateur réel, 2026-08-30).
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 3
                        : (constraints.maxWidth > 550 ? 2 : 1);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        // 2.0 restait encore trop court en 1 colonne : nom+badge, prix 28pt,
                        // durée+classe et le bouton "Modifier Tarif" ne tenaient pas dans la
                        // hauteur donnée, le texte chevauchait visuellement la carte suivante
                        // (retour utilisateur réel, captures d'écran, 2026-08-30).
                        childAspectRatio: crossAxisCount == 1 ? 1.1 : 1.4,
                      ),
                      itemCount: tiers.length,
                      itemBuilder: (context, idx) {
                        final tier = tiers[idx];
                        return _buildTierCard(
                          context,
                          tier,
                          _getTierColor(tier.name),
                        );
                      },
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context,
    SubscriptionTier tier,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tier.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tier.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${tier.price.toStringAsFixed(0)} FCFA',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Durée : ${tier.durationDays} jours',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              // La classe/le pays rattachés n'étaient affichés nulle part — le concept "tarif PAR
              // classe" annoncé par le sous-titre de la page était donc invisible depuis cet écran.
              FutureBuilder<AcademicNode?>(
                future: ref
                    .read(supabaseServiceProvider)
                    .getNode(tier.classNodeId),
                builder: (context, snapshot) => Text(
                  'Classe : ${snapshot.data?.name ?? '…'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.primaryBorder),
                ),
                onPressed: () => _showEditTierModal(context, tier: tier),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier Tarif'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tierName) {
    switch (tierName.toLowerCase()) {
      case 'gratuit':
        return Colors.white54;
      case 'journalier':
        return AppTheme.accentCyan;
      case 'hebdomadaire':
        return AppTheme.accentBlue;
      case 'mensuel':
        return AppTheme.accentEmerald;
      case 'annuel':
        return AppTheme.accentAmber;
      default:
        return AppTheme.accentBlue;
    }
  }

  void _showEditTierModal(BuildContext context, {SubscriptionTier? tier}) {
    final nameController = TextEditingController(text: tier?.name ?? '');
    final priceController = TextEditingController(
      text: tier?.price.toStringAsFixed(0) ?? '',
    );
    final durationController = TextEditingController(
      text: tier?.durationDays.toString() ?? '',
    );
    String? selectedCountryId = tier?.countryId;
    String? selectedClassNodeId = tier?.classNodeId;
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
            icon: Icons.price_change_rounded,
            text: tier == null
                ? 'Créer un Palier Tarifaire'
                : 'Modifier ${tier.name}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom du palier (ex: Mensuel, Journalier)',
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Prix en FCFA',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Durée de validité (en jours)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  // Le pays n'est PAS re-demandé ici : il est déjà fixé par le sélecteur de pays
                  // de la barre de navigation (un seul champ de vérité pour tout l'admin plutôt
                  // qu'un pays différent par formulaire). Si "Tous les pays" ou plusieurs pays
                  // sont actifs dans la navbar, on ne peut pas déduire un pays unique pour ce
                  // palier — l'admin doit d'abord restreindre la navbar à un seul pays.
                  if (tier == null) ...[
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final scopedCountryIds = ref.watch(
                          selectedCountryIdsProvider,
                        );
                        if (scopedCountryIds == null ||
                            scopedCountryIds.length != 1) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (selectedCountryId != null) {
                              setModalState(() => selectedCountryId = null);
                            }
                          });
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.accentAmber.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              'Sélectionnez un seul pays précis dans la barre de navigation en haut '
                              'de l\'écran avant de créer un palier ("Tous les pays" ou plusieurs '
                              'pays sélectionnés ne permettent pas de savoir à quel pays rattacher ce palier).',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentAmber,
                                height: 1.4,
                              ),
                            ),
                          );
                        }
                        final resolvedCountryId = scopedCountryIds.first;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (selectedCountryId != resolvedCountryId) {
                            setModalState(
                              () => selectedCountryId = resolvedCountryId,
                            );
                          }
                        });
                        final countryName = ref
                            .watch(nodesByTypeProvider('country'))
                            .valueOrNull
                            ?.where((c) => c.id == resolvedCountryId)
                            .firstOrNull
                            ?.name;
                        return Row(
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pays : ${countryName ?? '…'} (sélectionné dans la barre de navigation)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final classesAsync = ref.watch(
                          nodesByTypeProvider('class'),
                        );
                        final seriesAsync = ref.watch(
                          nodesByTypeProvider('series'),
                        );
                        final options =
                            <AcademicNode>[
                                  ...classesAsync.valueOrNull ?? [],
                                  ...seriesAsync.valueOrNull ?? [],
                                ]
                                .where(
                                  (c) =>
                                      selectedCountryId == null ||
                                      c.countryId == selectedCountryId,
                                )
                                .toList()
                              ..sort((a, b) => a.name.compareTo(b.name));
                        return DropdownButtonFormField<String?>(
                          // ignore: deprecated_member_use
                          value: selectedClassNodeId,
                          dropdownColor: AppTheme.primaryDark,
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Classe / Série',
                            prefixIcon: Icon(Icons.school_rounded, size: 20),
                          ),
                          items: options
                              .map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: selectedCountryId == null
                              ? null
                              : (v) => setModalState(
                                  () => selectedClassNodeId = v,
                                ),
                        );
                      },
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
            if (tier != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppTheme.accentRose,
                ),
                tooltip: 'Supprimer définitivement',
                onPressed: isLoading
                    ? null
                    : () => _showDeleteTierConfirmation(context, ctx, tier),
              ),
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: AppTheme.textMuted),
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
                      final price =
                          double.tryParse(priceController.text.trim()) ?? 0.0;
                      final duration =
                          int.tryParse(durationController.text.trim()) ?? 30;
                      if (name.isEmpty) {
                        setModalState(
                          () => fieldError = 'Le nom est obligatoire',
                        );
                        return;
                      }
                      if (tier == null &&
                          (selectedCountryId == null ||
                              selectedClassNodeId == null)) {
                        setModalState(
                          () => submitError =
                              'Pays et Classe/Série sont obligatoires.',
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
                        if (tier == null) {
                          await service.createTier(
                            name: name,
                            countryId: selectedCountryId!,
                            classNodeId: selectedClassNodeId!,
                            price: price,
                            durationDays: duration,
                          );
                        } else {
                          await service.updateTier(
                            tier.id,
                            name: name,
                            price: price,
                            durationDays: duration,
                          );
                        }
                        ref.invalidate(subscriptionTiersProvider(null));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                tier == null
                                    ? 'Palier "$name" créé avec succès !'
                                    : 'Palier "$name" mis à jour !',
                                style: GoogleFonts.inter(color: Colors.white),
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
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Suppression jusqu'ici sans AUCUNE confirmation (un clic sur l'icône poubelle supprimait
  /// immédiatement) — irréversible, contrairement à tous les autres flux de suppression de l'app.
  void _showDeleteTierConfirmation(
    BuildContext context,
    BuildContext editModalCtx,
    SubscriptionTier tier,
  ) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppDialogTitle(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.accentRose,
            text: 'Supprimer "${tier.name}" ?',
            onClose: () => Navigator.pop(dialogCtx),
          ),
          content: SizedBox(
            width: 420,
            child: Text(
              'IRRÉVERSIBLE : les élèves abonnés à ce palier ne seront plus rattachés à aucun tarif actif.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.deleteTier(tier.id);
                        ref.invalidate(subscriptionTiersProvider(null));
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (editModalCtx.mounted) Navigator.pop(editModalCtx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Palier "${tier.name}" supprimé.'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentRose,
                            content: Text('Erreur : $e'),
                          ),
                        );
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
                  : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }
}
