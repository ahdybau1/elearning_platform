import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/gamification_models.dart';
import '../../../core/theme/student_theme.dart';

/// Grille de badges — les gagnés sont allumés, les autres grisés avec leur seuil réel affiché
/// ("3/10 leçons"), jamais masqués (§14 : le badge existe comme objectif visible, pas une surprise).
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.badges});

  final List<BadgeProgress> badges;

  static const _icons = {
    'menu_book_rounded': Icons.menu_book_rounded,
    'auto_stories_rounded': Icons.auto_stories_rounded,
    'flag_rounded': Icons.flag_rounded,
    'military_tech_rounded': Icons.military_tech_rounded,
    'check_circle_rounded': Icons.check_circle_rounded,
    'workspace_premium_rounded': Icons.workspace_premium_rounded,
    'local_fire_department_rounded': Icons.local_fire_department_rounded,
    'whatshot_rounded': Icons.whatshot_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Text(
        'Aucun badge disponible pour le moment.',
        style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) => _BadgeTile(badge: badges[index], icons: _icons),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.icons});

  final BadgeProgress badge;
  final Map<String, IconData> icons;

  @override
  Widget build(BuildContext context) {
    final earned = badge.isEarned;
    final accent = earned ? context.colors.accentAmber : context.colors.textMuted;
    return Tooltip(
      message: badge.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: earned ? context.colors.accentAmber.withValues(alpha: 0.12) : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: earned ? context.colors.accentAmber.withValues(alpha: 0.4) : context.colors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[badge.iconKey] ?? Icons.emoji_events_outlined, size: 26, color: accent),
            const SizedBox(height: 6),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: earned ? context.colors.textPrimary : context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              earned ? 'Obtenu' : '${badge.currentValue}/${badge.criteriaThreshold}',
              style: GoogleFonts.inter(fontSize: 9.5, color: accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
