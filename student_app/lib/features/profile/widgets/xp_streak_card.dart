import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/gamification_models.dart';
import '../../../core/theme/student_theme.dart';
import '../../../design_system/tokens/app_radius.dart';

/// XP total + streak — extrait de `GamificationSummary` (calculé côté serveur, jamais un chiffre
/// inventé). Un streak à 0 s'affiche honnêtement comme "aucune activité aujourd'hui", jamais
/// habillé en une fausse progression.
class XpStreakCard extends StatelessWidget {
  const XpStreakCard({super.key, required this.summary});

  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.bolt_rounded,
              iconColor: context.colors.accentIndigo,
              value: '${summary.xp}',
              label: 'Points d\'expérience',
            ),
          ),
          Container(width: 1, height: 40, color: context.colors.border),
          Expanded(
            child: _Stat(
              icon: Icons.local_fire_department_rounded,
              iconColor: context.colors.accentAmber,
              value: summary.streakDays > 0 ? '${summary.streakDays}' : '0',
              label: summary.streakDays > 0
                  ? (summary.streakDays == 1 ? 'jour de suite' : 'jours de suite')
                  : 'Aucune activité aujourd\'hui',
            ),
          ),
          if (summary.longestStreak > summary.streakDays) ...[
            Container(width: 1, height: 40, color: context.colors.border),
            Expanded(
              child: _Stat(
                icon: Icons.emoji_events_outlined,
                iconColor: context.colors.textSecondary,
                value: '${summary.longestStreak}',
                label: 'Record de régularité',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 10.5, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
