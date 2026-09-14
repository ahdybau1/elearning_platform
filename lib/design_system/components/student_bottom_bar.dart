import 'package:flutter/material.dart';
import '../../core/theme/student_theme.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

class StudentBottomBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const StudentBottomBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class StudentBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<StudentBottomBarItem> items;
  final VoidCallback? onHide;

  const StudentBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onHide != null)
              InkWell(
                onTap: onHide,
                borderRadius: AppRadius.radiusFull,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 60,
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  final isAi = index == 3; // Mise en valeur discrète du Tuteur IA

              final activeColor = isAi ? AppColors.cyanAccent : colors.accentPrimary;
              final inactiveColor = colors.textMuted;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: AppRadius.radiusLarge,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 12 : 0,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Icon(
                          isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                          size: 22,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          color: isSelected ? activeColor : inactiveColor,
                          weight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    ),
  ),
);
  }
}
