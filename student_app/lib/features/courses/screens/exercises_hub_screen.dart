import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §3.2 du cahier des charges : structure à trois niveaux d'indépendance (liés à une leçon, liés à
/// un chapitre hors leçon, indépendants). Données de démonstration pour cette passe de conception —
/// la couche réelle de contenu (subjects/chapters/exercises) a un décalage de schéma connu qui doit
/// être corrigé dans une passe dédiée avant de brancher cette page sur de vraies requêtes.
class ExercisesHubScreen extends ConsumerWidget {
  const ExercisesHubScreen({super.key});

  static const _byLesson = [
    {'title': 'Nombres Complexes — Forme algébrique', 'subject': 'Mathématiques', 'count': 8, 'difficulty': 'Intermédiaire'},
    {'title': 'Limites & Continuité', 'subject': 'Mathématiques', 'count': 6, 'difficulty': 'Approfondissement'},
    {'title': 'Optique Ondulatoire', 'subject': 'Physique - Chimie', 'count': 5, 'difficulty': 'Simple'},
  ];

  static const _byChapter = [
    {'title': 'Entraînement général — Fonctions', 'subject': 'Mathématiques', 'count': 14, 'difficulty': 'Mixte'},
    {'title': 'Approfondissement — Mécanique', 'subject': 'Physique - Chimie', 'count': 10, 'difficulty': 'Approfondissement'},
  ];

  static const _independent = [
    {'title': 'Série Type Examen — Toutes Notions', 'subject': 'Mathématiques', 'count': 25, 'difficulty': 'Examen'},
    {'title': 'Révision Multi-Chapitres', 'subject': 'Français & Littérature', 'count': 12, 'difficulty': 'Mixte'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return StudentPageContent(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StudentScreenHeader(title: 'Exercices (${profile?.className ?? ''})'),
            const SizedBox(height: 24),
            _buildSection(context, 'Liés à une leçon', 'Créés par l\'enseignant et/ou générés par l\'IA', _byLesson, context.colors.accentPrimary),
            const SizedBox(height: 28),
            _buildSection(context, 'Entraînement de chapitre', 'Synthèse hors leçon précise, approfondissement', _byChapter, context.colors.accentIndigo),
            const SizedBox(height: 28),
            _buildSection(context, 'Indépendants (type examen)', 'Mélange de chapitres, accessibles depuis cette page générale', _independent, context.colors.accentAmber),
          ],
        ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String subtitle, List<Map<String, dynamic>> items, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
        const SizedBox(height: 14),
        ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.edit_note_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                        Text('${item['subject']} • ${item['count']} exercices • ${item['difficulty']}',
                            style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lancement de la série d\'exercices...')),
                    ),
                    child: const Text('Commencer'),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
