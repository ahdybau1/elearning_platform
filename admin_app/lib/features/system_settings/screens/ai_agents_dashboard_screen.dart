import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class AiAgentsDashboardScreen extends ConsumerWidget {
  const AiAgentsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Map<String, dynamic>> subjectCatalogs = [
      {
        'subject': 'Mathématiques',
        'elements': [
          'Définition',
          'Propriété',
          'Théorème',
          'Démonstration',
          'Exemple',
          'Exercice d\'application',
          'Exercice d\'approfondissement',
        ],
      },
      {
        'subject': 'Français',
        'elements': [
          'Texte support',
          'Biographie d\'auteur',
          'Notion grammaticale',
          'Figure de style',
          'Méthodologie dissertation',
          'Exercice de langue',
        ],
      },
      {
        'subject': 'Physique-Chimie',
        'elements': [
          'Définition',
          'Loi physique',
          'Formule',
          'Protocole d\'expérience',
          'Schéma montages',
          'Application numérique',
        ],
      },
      {
        'subject': 'SVT',
        'elements': [
          'Définition',
          'Schéma annoté',
          'Observation micrographique',
          'Protocole expérimental',
          'Bilan de synthèse',
        ],
      },
    ];

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
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter un Type d\'Élément au Catalogue'),
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

          // Catalog Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
              ),
              itemCount: subjectCatalogs.length,
              itemBuilder: (context, idx) {
                final cat = subjectCatalogs[idx];
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
                            cat['subject'],
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (cat['elements'] as List<String>).map((el) {
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
                              el,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
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
