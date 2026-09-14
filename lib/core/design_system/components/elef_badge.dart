import 'package:flutter/material.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_typography.dart';

enum ElefBadgeTone { subtle, solid, outline }

/// ELEF Design System — Badge Sémantique et Disciplinaire
class ElefBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final ElefBadgeTone tone;

  const ElefBadge({
    super.key,
    required this.label,
    this.color = ElefColors.primary,
    this.icon,
    this.tone = ElefBadgeTone.subtle,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;

    switch (tone) {
      case ElefBadgeTone.subtle:
        bg = color.withAlpha(30);
        fg = color;
        border = Border.all(color: color.withAlpha(80), width: 0.8);
        break;
      case ElefBadgeTone.solid:
        bg = color;
        fg = Colors.black;
        break;
      case ElefBadgeTone.outline:
        bg = Colors.transparent;
        fg = color;
        border = Border.all(color: color.withAlpha(160), width: 1);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ElefRadius.sm,
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: ElefTypography.badge.copyWith(color: fg, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// Chip cliquable pour filtres et tags
class ElefChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? activeColor;

  const ElefChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? ElefColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: ElefRadius.full,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(35) : ElefColors.surfaceDark,
          borderRadius: ElefRadius.full,
          border: Border.all(
            color: isSelected ? color : ElefColors.borderMedium,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? color : ElefColors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: ElefTypography.caption.copyWith(
                color: isSelected ? color : ElefColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
