import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Rentrée Scolaire 2026-2027 : Bienvenue à tous !',
      'message':
          'Découvrez les nouveaux cours et le module de révision adaptative par IA.',
      'urgency': 'info',
      'target': 'Tous les élèves (Cameroun)',
      'period': '01/09/2026 - 30/09/2026',
    },
    {
      'title': 'Maintenance Technique Programmée',
      'message':
          'L\'application sera indisponible ce dimanche de 02h à 04h du matin pour mise à jour des serveurs.',
      'urgency': 'warning',
      'target': 'Tous les utilisateurs',
      'period': '12/10/2026 - 13/10/2026',
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
                    'Gestion des Bannières d\'Annonces',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diffusion de messages ciblés par pays/classe avec affichage temporisé automatique',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Publier une Annonce'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _announcements.length,
              itemBuilder: (context, idx) {
                final ann = _announcements[idx];
                final isWarning = ann['urgency'] == 'warning';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isWarning
                          ? AppTheme.accentAmber
                          : AppTheme.primaryBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isWarning
                            ? AppTheme.accentAmber.withValues(alpha: 0.15)
                            : AppTheme.accentBlue.withValues(alpha: 0.15),
                        child: Icon(
                          isWarning
                              ? Icons.warning_rounded
                              : Icons.campaign_rounded,
                          color: isWarning
                              ? AppTheme.accentAmber
                              : AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ann['title'],
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ann['message'],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cible : ${ann['target']} • Période : ${ann['period']}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.accentRose,
                        ),
                        onPressed: () {},
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
}
