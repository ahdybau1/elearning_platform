import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class WhatsappGroupsScreen extends StatefulWidget {
  const WhatsappGroupsScreen({super.key});

  @override
  State<WhatsappGroupsScreen> createState() => _WhatsappGroupsScreenState();
}

class _WhatsappGroupsScreenState extends State<WhatsappGroupsScreen> {
  final List<Map<String, dynamic>> _groups = [
    {
      'class': 'Classe de 3ème (Général)',
      'inviteLink': 'https://chat.whatsapp.com/Km89Xz...',
      'members': '~ 850 membres',
      'status': 'Actif',
    },
    {
      'class': 'Classe de Terminale C',
      'inviteLink': 'https://chat.whatsapp.com/TleC2026...',
      'members': '~ 420 membres',
      'status': 'Actif',
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
                    'Communautés d\'Étude WhatsApp Officielles',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestion des liens d\'invitation des groupes WhatsApp officiels par classe (Cloisonnement strict)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                ),
                onPressed: () {},
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Ajouter un Lien WhatsApp'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (context, idx) {
                final grp = _groups[idx];
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
                        backgroundColor: AppTheme.accentEmerald.withValues(
                          alpha: 0.15,
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              grp['class'],
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lien : ${grp['inviteLink']} • ${grp['members']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white70,
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
