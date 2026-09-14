import 'package:flutter/material.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_spacing.dart';

enum ElefCardVariant { outlined, filled, elevated }

/// ELEF Design System — Conteneur Élégant sans Encombrement
class ElefCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final ElefCardVariant variant;
  final BorderRadius? borderRadius;

  const ElefCard({
    super.key,
    required this.child,
    this.padding = ElefSpacing.paddingMd,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.variant = ElefCardVariant.outlined,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Border? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case ElefCardVariant.outlined:
        bg = backgroundColor ?? ElefColors.surfaceCard;
        border = Border.all(
          color: borderColor ?? ElefColors.borderMedium,
          width: 1,
        );
        break;
      case ElefCardVariant.filled:
        bg = backgroundColor ?? ElefColors.surfaceDark;
        border = Border.all(
          color: borderColor ?? ElefColors.borderSubtle,
          width: 1,
        );
        break;
      case ElefCardVariant.elevated:
        bg = backgroundColor ?? ElefColors.surfaceElevated;
        border = Border.all(
          color: borderColor ?? ElefColors.borderMedium,
          width: 1,
        );
        shadow = [
          const BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ];
        break;
    }

    final effectiveRadius = borderRadius ?? ElefRadius.lg;

    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: effectiveRadius,
        border: border,
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: container,
        ),
      );
    }

    return container;
  }
}
