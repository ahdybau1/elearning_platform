import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class SchoolPapersScreen extends StatefulWidget {
  const SchoolPapersScreen({super.key});

  @override
  State<SchoolPapersScreen> createState() => _SchoolPapersScreenState();
}

class _SchoolPapersScreenState extends State<SchoolPapersScreen> {
  final List<Map<String, dynamic>> _establishments = [
    {
      'name': 'Lycée Général Leclerc',
      'city': 'Yaoundé',
      'papersCount': '124 épreuves enregistrées',
    },
    {
      'name': 'Collège Francois-Xavier Vogt',
      'city': 'Yaoundé',
      'papersCount': '98 épreuves enregistrées',
    },
    {
      'name': 'Lycée Jost',
      'city': 'Douala',
      'papersCount': '45 épreuves enregistrées',
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
                    'Gestion des Épreuves par Établissement',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Devoirs et compositions internes propres à chaque lycée/collège (Catalogue ouvert à tous les élèves)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEstablishmentModal(context),
                icon: const Icon(Icons.domain_add_rounded, size: 18),
                label: const Text('Créer un Établissement'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _establishments.length,
              itemBuilder: (context, idx) {
                final est = _establishments[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.accentIndigo.withValues(
                          alpha: 0.15,
                        ),
                        child: const Icon(
                          Icons.domain_rounded,
                          color: AppTheme.accentIndigo,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              est['name'],
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ville : ${est['city']} • ${est['papersCount']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text('Voir Épreuves'),
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

  void _showAddEstablishmentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        title: AppDialogTitle(
          icon: Icons.domain_add_rounded,
          text: 'Créer un Établissement Physique',
          onClose: () => Navigator.pop(context),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText:
                      'Nom de l\'établissement (ex: Lycée de Biyem-Assi)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Ville / Région'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Créer l\'établissement'),
          ),
        ],
      ),
    );
  }
}
