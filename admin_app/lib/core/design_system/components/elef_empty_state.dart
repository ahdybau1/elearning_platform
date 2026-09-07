import 'package:flutter/material.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_spacing.dart';
import '../tokens/elef_typography.dart';
import 'elef_button.dart';

/// ELEF Design System — État Vide & Placeholder Pédagogique
class ElefEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ElefEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ElefSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ElefColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: ElefColors.borderMedium),
              ),
              child: Icon(icon, size: 32, color: ElefColors.textMuted),
            ),
            const SizedBox(height: ElefSpacing.md),
            Text(
              title,
              style: ElefTypography.heading3.copyWith(color: ElefColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ElefSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                description,
                style: ElefTypography.bodySmall.copyWith(color: ElefColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: ElefSpacing.lg),
              ElefButton(
                label: actionLabel!,
                onPressed: onAction!,
                variant: ElefButtonVariant.primary,
                size: ElefButtonSize.sm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
