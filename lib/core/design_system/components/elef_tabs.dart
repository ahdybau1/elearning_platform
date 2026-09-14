import 'package:flutter/material.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_typography.dart';

/// ELEF Design System — Barre d'Onglets Segmentée Épurée
class ElefTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<IconData>? icons;

  const ElefTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ElefColors.surfaceDark,
        borderRadius: ElefRadius.md,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: ElefRadius.sm,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? ElefColors.surfaceCard : Colors.transparent,
                  borderRadius: ElefRadius.sm,
                  border: isSelected
                      ? Border.all(color: ElefColors.borderMedium)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icons != null && index < icons!.length) ...[
                      Icon(
                        icons![index],
                        size: 14,
                        color: isSelected
                            ? ElefColors.primaryHover
                            : ElefColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      tabs[index],
                      style: ElefTypography.caption.copyWith(
                        color: isSelected
                            ? ElefColors.textPrimary
                            : ElefColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
