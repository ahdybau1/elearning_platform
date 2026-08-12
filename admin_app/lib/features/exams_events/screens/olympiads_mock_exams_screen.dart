import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class OlympiadsMockExamsScreen extends StatefulWidget {
  const OlympiadsMockExamsScreen({super.key});

  @override
  State<OlympiadsMockExamsScreen> createState() =>
      _OlympiadsMockExamsScreenState();
}

class _OlympiadsMockExamsScreenState extends State<OlympiadsMockExamsScreen> {
  int _activeSubTab = 0; // 0: Événements, 1: Contestations de Notes (Disputes)

  final List<Map<String, dynamic>> _events = [
    {
      'title': 'Grand Examen Blanc National BEPC 2026',
      'type': 'Examen Blanc',
      'targetClass': 'Classe de 3ème',
      'period': '15 Nov 2026 - 20 Nov 2026',
      'pricing': 'Inclus dans abonnement',
      'participants': '4,520 élèves inscrits',
    },
    {
      'title': 'Olympiades Nationales de Mathématiques',
      'type': 'Olympiade',
      'targetClass': 'Toutes les classes',
      'period': '01 Dec 2026 - 05 Dec 2026',
      'pricing': 'Payant (500 FCFA)',
      'participants': '1,200 élèves inscrits',
    },
  ];

  final List<Map<String, dynamic>> _gradeDisputes = [
    {
      'id': 'disp-001',
      'student': 'Junior Atangana (Profil 3e)',
      'event': 'Examen Blanc Mathématiques',
      'originalScore': '12 / 20',
      'grader1': 'M. Atangana (Correcteur 1)',
      'motive':
          'Raisonnement correct à la question 3, seule l\'unité finale est fausse. Demande révision.',
      'assignedGrader2': 'Mme. Ngo Ndjo (Correcteur 2 - Règle d\'impartialité)',
      'status': 'En cours de relecture',
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
                    'Olympiades & Contestations de Notes',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestion des événements compétitifs et file des réclamations avec 2nd correcteur obligatoire',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer un Événement'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sub tabs
          Row(
            children: [
              _buildSubTab(0, 'Événements & Concours (${_events.length})'),
              const SizedBox(width: 12),
              _buildSubTab(
                1,
                'Contestations de Notes (${_gradeDisputes.length})',
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _activeSubTab == 0
                ? _buildEventsView()
                : _buildDisputesView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int idx, String label) {
    final isSelected = _activeSubTab == idx;
    return InkWell(
      onTap: () => setState(() => _activeSubTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.primaryBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildEventsView() {
    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, idx) {
        final ev = _events[idx];
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
                backgroundColor: AppTheme.accentAmber.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppTheme.accentAmber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev['title'],
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ev['targetClass']} • ${ev['period']} • ${ev['pricing']}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ev['participants'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.accentEmerald,
                        fontWeight: FontWeight.w600,
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
                icon: const Icon(Icons.grading_rounded, size: 16),
                label: const Text('Interface de Correction'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisputesView() {
    return ListView.builder(
      itemCount: _gradeDisputes.length,
      itemBuilder: (context, idx) {
        final disp = _gradeDisputes[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentAmber),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Réclamation : ${disp['student']}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Note initiale : ${disp['originalScore']}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Événement : ${disp['event']} • Initialement corrigé par : ${disp['grader1']}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Motif de l\'élève : "${disp['motive']}"',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 14,
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Assigné au 2nd Correcteur : ${disp['assignedGrader2']}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Maintenir 12/20'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                    ),
                    onPressed: () {
                      setState(() => _gradeDisputes.removeAt(idx));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Note révisée à 14/20. L\'élève recevra une notification automatique.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Réviser la Note (ex: 14/20)'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
