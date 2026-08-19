import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

class AiAgentsDashboardScreen extends ConsumerWidget {
  const AiAgentsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider((countryId: null, includeInactive: false)));

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
                    'Agents IA & Catalogues Pédagogiques',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Routage multi-modèles (Claude / Gemini), suivi des coûts API et catalogue d\'éléments par matière',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                ),
                // Renvoie vers l'écran dédié plutôt que de dupliquer sa logique de création ici
                // (voir 05_flutter_architecture.md, règle 4 : pas de logique dupliquée).
                onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 22,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Gérer le Catalogue Pédagogique'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Routing Strategy Summary Cards
          Row(
            children: [
              _buildModelCard(
                'Claude Sonnet (Anthropic)',
                'Structuration & Exercices',
                'Haute précision pédagogique',
                '0.003 \$ / 1k tokens',
                AppTheme.accentBlue,
              ),
              const SizedBox(width: 16),
              _buildModelCard(
                'Gemini Flash (Google)',
                'Modération Forum Massique',
                'Gratuit en Free Tier / Haut Volume',
                '0.0001 \$ / 1k tokens',
                AppTheme.accentEmerald,
              ),
              const SizedBox(width: 16),
              _buildModelCard(
                'Gemini Multimodal (Google)',
                'OCR Scans Manuscrits',
                'Vision native d\'images',
                '0.002 \$ / image',
                AppTheme.accentCyan,
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text(
            'Catalogue Exhaustif des Éléments Pédagogiques par Matière (Prérequis IA)',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Catalog Grid — données réelles (content_catalog), un onglet par matière
          Expanded(
            child: subjectsAsync.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return Center(
                    child: Text('Aucune matière créée.',
                        style: GoogleFonts.inter(color: AppTheme.textMuted)),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, idx) {
                final subject = subjects[idx];
                final catalogAsync = ref.watch(contentCatalogProvider(subject.id));
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
                            subject.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Icon(
                            Icons.category_rounded,
                            size: 18,
                            color: AppTheme.accentCyan,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: catalogAsync.when(
                          data: (items) {
                            if (items.isEmpty) {
                              return Text(
                                'Aucun élément de catalogue pour cette matière.',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                              );
                            }
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: items.map((item) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryDark,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.elementType,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (err, _) => Text('Erreur: $err',
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentRose)),
                        ),
                      ),
                    ],
                  ),
                );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(
    String name,
    String task,
    String reason,
    String rate,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tâche : $task',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reason,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
