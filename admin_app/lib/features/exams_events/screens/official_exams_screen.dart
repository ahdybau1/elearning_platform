import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class OfficialExamsScreen extends StatefulWidget {
  const OfficialExamsScreen({super.key});

  @override
  State<OfficialExamsScreen> createState() => _OfficialExamsScreenState();
}

class _OfficialExamsScreenState extends State<OfficialExamsScreen> {
  final List<Map<String, dynamic>> _officialExams = [
    {
      'name': 'BEPC (Brevet d\'Études du Premier Cycle)',
      'class': 'Classe de 3ème',
      'examDate': '08 Juin 2027',
      'papersCount': '45 Sujets & Corrigés (2015-2026)',
    },
    {
      'name': 'Probatoire C & D (Enseignement Général)',
      'class': 'Classe de 1ère',
      'examDate': '01 Juin 2027',
      'papersCount': '60 Sujets & Corrigés',
    },
    {
      'name': 'Baccalauréat C, A4, TI',
      'class': 'Classe de Terminale',
      'examDate': '25 Mai 2027',
      'papersCount': '95 Sujets & Corrigés',
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
                    'Gestion des Examens Officiels Nationaux',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sujets et corrigés d\'examens officiels (BEPC, Probatoire, Baccalauréat Cameroun)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Uploader un Sujet / Corrigé'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _officialExams.length,
              itemBuilder: (context, idx) {
                final exam = _officialExams[idx];
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
                          Icons.workspace_premium_rounded,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam['name'],
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exam['class']} • Date officielle : ${exam['examDate']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exam['papersCount'],
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
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Gérer les Sujets'),
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
