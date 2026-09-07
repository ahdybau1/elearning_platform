import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../../../core/models/summary_sheet_registry.dart';
import '../../courses/widgets/summary_sheet_viewer_modal.dart';

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
                title: 'Boutique & Fiches Mémo (${profile?.className ?? ''})',
              ),
              const SizedBox(height: 20),

              // Section Fiches de Synthèse Officielles HD (Option 3)
              _buildSummarySheetsSection(context),
              const SizedBox(height: 28),

              // Section Documents & Livrets payants à la carte
              Text(
                'Livrets d\'Exercices & Annales à la carte',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (documents.isEmpty)
                EmptyStateView(
                  icon: Icons.menu_book_outlined,
                  title: 'Aucun livret supplémentaire',
                  description:
                      'Les fiches de synthèse officielles ci-dessus sont déjà disponibles pour ${profile?.className ?? 'votre classe'}.',
                  iconColor: context.colors.accentIndigo,
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

  /// Section dédiée aux Fiches Mémo & Résumés Officiels (HD & Formules)
  Widget _buildSummarySheetsSection(BuildContext context) {
    final sheets = SummarySheetRegistry.sheets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withAlpha(35),
                borderRadius: AppRadius.radiusSmall,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primaryCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fiches Mémo de Synthèse Officielles',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  'Revue rapide • Zoom HD tactile • Formules mathématiques officielles',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...sheets.map((sheet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSummarySheetCard(context, sheet),
            )),
      ],
    );
  }

  Widget _buildSummarySheetCard(BuildContext context, SummarySheet sheet) {
    final isMath = sheet.subject.toLowerCase().contains('math');
    final accentColor = isMath ? AppColors.primaryCyan : AppColors.accentAmber;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(
          color: accentColor.withAlpha(80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(30),
                  borderRadius: AppRadius.radiusSmall,
                  border: Border.all(color: accentColor.withAlpha(120)),
                ),
                child: Text(
                  sheet.subject.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.accentEmerald.withAlpha(30),
                  borderRadius: AppRadius.radiusSmall,
                ),
                child: Text(
                  'INCLUS / ACCÈS LIBRE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.colors.accentEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sheet.title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Niveau : ${sheet.level} • ${sheet.sections.length} sections canoniques détaillées',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                elevation: 0,
              ),
              onPressed: () => SummarySheetViewerModal.show(context, sheet),
              icon: const Icon(Icons.zoom_in_rounded, size: 18),
              label: const Text(
                'Consulter la Fiche Mémo HD (Zoom & Formules)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, ShopDocument doc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
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
                  borderRadius: AppRadius.radiusSmall,
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
                  borderRadius: AppRadius.radiusSmall,
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
