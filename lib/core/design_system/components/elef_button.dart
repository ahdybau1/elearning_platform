import 'package:flutter/material.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_spacing.dart';
import '../tokens/elef_typography.dart';

enum ElefButtonVariant { primary, secondary, outline, ghost, danger }
enum ElefButtonSize { sm, md, lg }

/// ELEF Design System — Bouton Universel Haute Fidélité
class ElefButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ElefButtonVariant variant;
  final ElefButtonSize size;
  final bool isLoading;
  final bool fullWidth;

  const ElefButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = ElefButtonVariant.primary,
    this.size = ElefButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
  });

  const ElefButton.primary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.size = ElefButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ElefButtonVariant.primary;

  const ElefButton.secondary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.size = ElefButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ElefButtonVariant.secondary;

  const ElefButton.outline({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.size = ElefButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ElefButtonVariant.outline;

  const ElefButton.ghost({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.size = ElefButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ElefButtonVariant.ghost;

  const ElefButton.danger({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.size = ElefButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ElefButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case ElefButtonVariant.primary:
        bg = ElefColors.primary;
        fg = const Color(0xFF0F172A);
        break;
      case ElefButtonVariant.secondary:
        bg = ElefColors.secondary;
        fg = Colors.white;
        break;
      case ElefButtonVariant.outline:
        bg = Colors.transparent;
        fg = ElefColors.textPrimary;
        border = const BorderSide(color: ElefColors.borderMedium);
        break;
      case ElefButtonVariant.ghost:
        bg = Colors.transparent;
        fg = ElefColors.textSecondary;
        break;
      case ElefButtonVariant.danger:
        bg = ElefColors.dangerBg;
        fg = ElefColors.danger;
        border = const BorderSide(color: ElefColors.dangerBorder);
        break;
    }

    final verticalPadding = size == ElefButtonSize.sm
        ? 8.0
        : size == ElefButtonSize.md
            ? 12.0
            : 16.0;

    final horizontalPadding = size == ElefButtonSize.sm
        ? 14.0
        : size == ElefButtonSize.md
            ? 20.0
            : 24.0;

    final textStyle = size == ElefButtonSize.sm
        ? ElefTypography.caption.copyWith(fontWeight: FontWeight.bold, color: fg)
        : size == ElefButtonSize.md
            ? ElefTypography.titleSmall.copyWith(fontWeight: FontWeight.w600, color: fg)
            : ElefTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: fg);

    final buttonContent = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: size == ElefButtonSize.sm ? 14 : 18,
            height: size == ElefButtonSize.sm ? 14 : 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: ElefSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: size == ElefButtonSize.sm ? 16 : 18, color: fg),
          const SizedBox(width: ElefSpacing.sm),
        ],
        Text(label, style: textStyle),
      ],
    );

    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: ElefRadius.md,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withAlpha(80) : bg,
          borderRadius: ElefRadius.md,
          border: border == BorderSide.none ? null : Border.fromBorderSide(border),
        ),
        child: buttonContent,
      ),
    );
  }
}
