import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §32.1 du cahier des charges : documents pédagogiques à la carte. `shop_documents` est une vraie
/// table, gérée côté admin ; le seul point encore honnêtement indisponible est le paiement lui-même
/// (aucun agrégateur Mobile Money connecté — voir le message sur le bouton d'achat).
class BoutiqueShopScreen extends ConsumerWidget {
  const BoutiqueShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final documentsAsync = profile == null
        ? const AsyncValue<List<ShopDocument>>.data([])
        : ref.watch(shopDocumentsProvider(profile.classNodeId));

    return StudentPageContent(
      child: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Erreur : $err', style: TextStyle(color: context.colors.accentRose)),
        ),
        data: (documents) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StudentScreenHeader(
                title: 'Boutique de Fiches & Livrets (${profile?.className ?? ''})',
              ),
              const SizedBox(height: 20),
              if (documents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_outlined, color: context.colors.textMuted, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun document disponible pour ${profile?.className ?? 'votre classe'} pour le moment.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                ...documents.map((doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildDocCard(context, doc),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, ShopDocument doc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.accentIndigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DOCUMENT OFFICIEL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.colors.accentIndigo,
                  ),
                ),
              ),
              Text(
                '${doc.price.toStringAsFixed(0)} FCFA',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            doc.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          if (doc.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              doc.description!,
              style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${doc.downloadsCount} téléchargement${doc.downloadsCount > 1 ? 's' : ''}',
            style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.surface,
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                // Aucun agrégateur Mobile Money réel n'est encore connecté (voir
                // docs/cahier_des_charges.md §32.1) — un faux message de succès local ferait
                // croire à un achat réel sans transaction ni téléchargement. On le dit
                // honnêtement plutôt que de simuler la réussite.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: context.colors.accentAmber,
                    content: const Text(
                      'Paiement Mobile Money pas encore disponible : configuration de l\'agrégateur en attente.',
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.shopping_cart_checkout_rounded,
                size: 16,
                color: context.colors.accentPrimary,
              ),
              label: Text(
                'Acheter pour ${doc.price.toStringAsFixed(0)} FCFA (Mobile Money)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
