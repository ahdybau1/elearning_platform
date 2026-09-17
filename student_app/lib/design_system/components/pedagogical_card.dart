import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/student_theme.dart';
import '../tokens/app_radius.dart';

/// Carte pédagogique universelle pour l'application élève EDLEARN.
/// Fournit un fond texturé doux, une bordure subtilement teintée et une typographie soignée.
class PedagogicalCard extends StatelessWidget {
  final Widget child;
  final Widget? headerLeading;
  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool hasGlow;

  const PedagogicalCard({
    super.key,
    required this.child,
    this.headerLeading,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.accentColor,
    this.padding,
    this.margin,
    this.onTap,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveAccent = accentColor ?? colors.accentPrimary;

    Widget cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(
          color: hasGlow
              ? effectiveAccent.withValues(alpha: 0.4)
              : colors.border.withValues(alpha: 0.7),
          width: hasGlow ? 1.5 : 1.0,
        ),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: effectiveAccent.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusLarge,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null || headerLeading != null || headerTrailing != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (headerLeading != null) ...[
                      headerLeading!,
                      const SizedBox(width: 12),
                    ],
                    if (title != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title!,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ?headerTrailing,
                  ],
                ),
                const SizedBox(height: 14),
              ],
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLarge,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
