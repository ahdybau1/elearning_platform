import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';

class MockExamArenaScreen extends StatefulWidget {
  const MockExamArenaScreen({super.key});

  @override
  State<MockExamArenaScreen> createState() => _MockExamArenaScreenState();
}

class _MockExamArenaScreenState extends State<MockExamArenaScreen> {
  final List<Map<String, dynamic>> _leaderboard = [
    {'rank': 1, 'name': 'Junior K.', 'school': 'Lycée Leclerc Yaoundé', 'score': '19.5/20', 'time': '1h 42m'},
    {'rank': 2, 'name': 'Amina D.', 'school': 'Collège Libermann Douala', 'score': '19.0/20', 'time': '1h 50m'},
    {'rank': 3, 'name': 'Éric T.', 'school': 'Lycée Classique de Bafoussam', 'score': '18.5/20', 'time': '1h 55m'},
    {'rank': 4, 'name': 'Sandrine M.', 'school': 'Lycée Bilingue d\'Essos', 'score': '18.0/20', 'time': '2h 00m'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Arène des Examens Blancs & Olympiades',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Olympiade Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('SESSION NATIONALE OUVERTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.timer_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Clôture dans 3h 15m', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Grand Concours Blanc Mathématiques — Terminale C',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Épreuve type nationale de 4 heures avec classement en temps réel et bourses d\'études pour le Top 10.',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lancement de l\'épreuve chronométrée...')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                    label: const Text('Participer à l\'Épreuve', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Contestation de Note Callout (Section 11 du CDC : 2e Correcteur)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: StudentTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudentTheme.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: StudentTheme.accentRose.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: StudentTheme.accentRose, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contestation de Note (2e Correcteur)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Une erreur sur votre correction ? Déclenchez une 2nde relecture impartiale garantie.',
                          style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentTheme.surfaceDark,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: StudentTheme.borderDark),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showDisputeModal(context),
                    child: const Text('Contester', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Leaderboard Section
            Text(
              'Classement National en Direct',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 14),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _leaderboard.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _leaderboard[index];
                final isTop3 = index < 3;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: StudentTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTop3 ? StudentTheme.accentAmber.withOpacity(0.4) : StudentTheme.borderDark,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isTop3 ? StudentTheme.accentAmber : StudentTheme.surfaceDark,
                        ),
                        child: Center(
                          child: Text(
                            '#${item['rank']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isTop3 ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              item['school'],
                              style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item['score'],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: StudentTheme.accentEmerald,
                            ),
                          ),
                          Text(
                            item['time'],
                            style: GoogleFonts.firaCode(fontSize: 11, color: StudentTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDisputeModal(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudentTheme.cardDark,
        title: Row(
          children: const [
            Icon(Icons.gavel_rounded, color: StudentTheme.accentRose),
            SizedBox(width: 10),
            Text('Demande de 2e Correcteur', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Règle du CDC (Section 11) : Votre copie sera transmise à un examinateur neutre indépendant sans communication de la 1ère note pour garantir l\'équité.',
              style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Précisez l\'exercice ou la question contestée...',
                hintStyle: const TextStyle(color: StudentTheme.textMuted),
                filled: true,
                fillColor: StudentTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: StudentTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentTheme.accentRose),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: StudentTheme.accentEmerald,
                  content: Text('Demande de réclamation enregistrée. Attente de la 2nde notation.'),
                ),
              );
            },
            child: const Text('Soumettre au 2e Correcteur', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
