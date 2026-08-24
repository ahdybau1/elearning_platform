import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

class BoutiqueShopScreen extends ConsumerWidget {
  const BoutiqueShopScreen({super.key});

  final List<Map<String, dynamic>> _documents = const [
    {
      'id': '1',
      'title': 'Formulaire Exhaustif Mathématiques (Toutes Séries)',
      'author': 'Inspecteur Pédagogique National',
      'pages': 24,
      'price': '500 FCFA',
      'downloads': 1420,
    },
    {
      'id': '2',
      'title': 'Les 50 Pièges Mortels du Baccalauréat Scientifique',
      'author': 'Collectif des Enseignants d\'Élite',
      'pages': 38,
      'price': '1 000 FCFA',
      'downloads': 890,
    },
    {
      'id': '3',
      'title': 'Méthode de la Dissertation Philosophique Parfaite',
      'author': 'Pr. Nguema',
      'pages': 16,
      'price': '500 FCFA',
      'downloads': 650,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return StudentPageContent(child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _documents.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return StudentScreenHeader(title: 'Boutique de Fiches & Livrets (${profile?.className ?? ''})');
          }
          final doc = _documents[index - 1];
          return _buildDocCard(context, doc);
        },
      ));
  }

  Widget _buildDocCard(BuildContext context, Map<String, dynamic> doc) {
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
                        color: context.colors.accentIndigo.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DOCUMENT OFFICIEL (${doc['pages']} pages)',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.colors.accentIndigo,
                        ),
                      ),
                    ),
                    Text(
                      doc['price'],
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
                  doc['title'],
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Par ${doc['author']} • ${doc['downloads']} téléchargements',
                  style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      // Aucun agrégateur Mobile Money réel n'est encore connecté (voir
                      // docs/cahier_des_charges.md §32.1) — un faux message de succès local ferait
                      // croire à un achat réel sans transaction ni téléchargement. On le dit
                      // honnêtement plutôt que de simuler la réussite.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: context.colors.accentAmber,
                          content: Text(
                            'Paiement Mobile Money pas encore disponible : configuration de l\'agrégateur en attente.',
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.shopping_cart_checkout_rounded, size: 16, color: context.colors.accentPrimary),
                    label: Text(
                      'Acheter pour ${doc['price']} (Mobile Money)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
