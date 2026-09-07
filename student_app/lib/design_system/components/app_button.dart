import 'package:flutter/material.dart';
import '../../core/theme/student_theme.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

enum AppButtonVariant { primary, secondary, success, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = AppSpacing.space48,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = AppSpacing.space48,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.success({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = AppSpacing.space48,
  }) : variant = AppButtonVariant.success;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = AppSpacing.space40,
  }) : variant = AppButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = colors.accentPrimary;
        fgColor = Colors.black;
        break;
      case AppButtonVariant.secondary:
        bgColor = colors.surface;
        fgColor = colors.textPrimary;
        borderSide = BorderSide(color: colors.border, width: 1);
        break;
      case AppButtonVariant.success:
        bgColor = colors.accentEmerald;
        fgColor = Colors.black;
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = colors.accentPrimary;
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fgColor),
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: AppSpacing.space8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(color: fgColor, weight: FontWeight.bold),
            ),
          ),
        ],
      );
    } else {
      content = Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label(color: fgColor, weight: FontWeight.bold),
      );
    }

    final buttonWidget = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        minimumSize: Size(isFullWidth ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusMedium,
          side: borderSide,
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: buttonWidget);
    }
    return buttonWidget;
  }
}
