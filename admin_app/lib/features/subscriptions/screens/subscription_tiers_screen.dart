import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/providers/data_providers.dart';

class SubscriptionTiersScreen extends ConsumerStatefulWidget {
  const SubscriptionTiersScreen({super.key});

  @override
  ConsumerState<SubscriptionTiersScreen> createState() =>
      _SubscriptionTiersScreenState();
}

class _SubscriptionTiersScreenState
    extends ConsumerState<SubscriptionTiersScreen> {
  final String _selectedCountry = 'Cameroun';

  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(subscriptionTiersProvider(null));

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
                    'Paliers d\'Abonnement & Grille Tarifaire',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configuration des tarifs par classe et par durée ($_selectedCountry MVP)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
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
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
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
              Text(
                tier.name,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          tier == null ? 'Créer un Palier' : 'Modifier ${tier.name}',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du palier'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Prix en FCFA'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Durée de validité (jours)',
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              final service = ref.read(supabaseServiceProvider);
              if (tier == null) {
                await service.createTier(
                  name: nameController.text,
                  countryId: '',
                  classNodeId: '',
                  price: double.parse(priceController.text),
                  durationDays: int.parse(durationController.text),
                );
              } else {
                await service.updateTier(
                  tier.id,
                  price: double.parse(priceController.text),
                  durationDays: int.parse(durationController.text),
                );
              }
              ref.refresh(subscriptionTiersProvider(null));
              Navigator.pop(context);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
}
