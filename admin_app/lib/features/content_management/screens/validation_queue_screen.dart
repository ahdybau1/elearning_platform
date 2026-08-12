import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class ValidationQueueScreen extends StatefulWidget {
  const ValidationQueueScreen({super.key});

  @override
  State<ValidationQueueScreen> createState() => _ValidationQueueScreenState();
}

class _ValidationQueueScreenState extends State<ValidationQueueScreen> {
  final List<Map<String, dynamic>> _queueItems = [
    {
      'id': 'val-001',
      'title': 'Leçon 3 : Triangle rectangle et trigonométrie',
      'type': 'Leçon (Cours)',
      'author': 'M. Atangana (Enseignant)',
      'submittedAt': '10/10/2026 à 14:20',
      'aiScore': '96%',
      'aiFindings':
          '• Orthographe : 0 erreur détectée.\n• Structure : Introduction et résumé présent.\n• Conformité catalogue : Validé.',
      'aiStatusColor': AppTheme.accentEmerald,
    },
    {
      'id': 'val-002',
      'title': '10 Exercices QCM : Calcul vectoriel et repérage',
      'type': 'Exercices (Générés par IA)',
      'author': 'Agent IA (Claude Sonnet)',
      'submittedAt': '10/10/2026 à 12:05',
      'aiScore': '88%',
      'aiFindings':
          '• Vérification mathématique : 100% exact.\n• Remarque : L\'exercice 4 manque d\'explication détaillée dans la solution.',
      'aiStatusColor': AppTheme.accentAmber,
    },
    {
      'id': 'val-003',
      'title': 'Sujet d\'évaluation Blanc : Chimie organique Tle C',
      'type': 'Épreuve Établissement',
      'author': 'Mme. Ngo Ndjo (Admin Contenu)',
      'submittedAt': '09/10/2026 à 18:40',
      'aiScore': '92%',
      'aiFindings':
          '• Schémas moléculaires vérifiés.\n• Conformité au programme national : Validé.',
      'aiStatusColor': AppTheme.accentEmerald,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    'File de Validation des Contenus',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Workflow strict : Pré-analyse automatique par IA + Décision finale systématiquement humaine',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentAmber),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: AppTheme.accentAmber,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_queueItems.length} contenus à réviser',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: _queueItems.length,
              itemBuilder: (context, idx) {
                final item = _queueItems[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['type'],
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Auteur : ${item['author']}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item['submittedAt'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'],
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // AI Pre-Analysis findings box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (item['aiStatusColor'] as Color).withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: (item['aiStatusColor'] as Color)
                                  .withValues(alpha: 0.2),
                              child: Text(
                                item['aiScore'],
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item['aiStatusColor'],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rapport de Pré-analyse IA (Claude / Gemini)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['aiFindings'],
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Validation Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentRose,
                              side: const BorderSide(
                                color: AppTheme.accentRose,
                              ),
                            ),
                            onPressed: () =>
                                _showRejectModal(context, item['title']),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Rejeter avec Motif'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppTheme.primaryBorder,
                              ),
                            ),
                            onPressed: () {},
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Corriger & Éditer'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                            onPressed: () {
                              setState(() => _queueItems.removeAt(idx));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Contenu validé et publié aux élèves avec succès !',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                            ),
                            label: const Text('Approuver & Publier'),
                          ),
                        ],
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

  void _showRejectModal(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: Text(
          'Rejeter "$title"',
          style: GoogleFonts.outfit(color: AppTheme.accentRose),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Veuillez préciser le motif du rejet. L\'auteur recevra une notification automatique avec vos remarques pour correction.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              TextField(
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Ex: Exemples manquants, coquille dans la question 3...',
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Confirmer le Rejet'),
          ),
        ],
      ),
    );
  }
}
