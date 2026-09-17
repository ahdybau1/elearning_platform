import 'package:flutter/material.dart';
import '../../core/theme/student_theme.dart';
import '../tokens/app_colors.dart';

/// Barre de progression animée et valorisante pour le parcours d'apprentissage et les exercices.
class GamifiedProgressBar extends StatelessWidget {
  final double progress; // entre 0.0 et 1.0
  final double height;
  final Gradient? gradient;
  final Color? backgroundColor;
  final bool hasGlow;

  const GamifiedProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.gradient,
    this.backgroundColor,
    this.hasGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clamped = progress.clamp(0.0, 1.0);
    final effectiveGradient = gradient ?? AppColors.primaryGradient;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          return Stack(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0.0, end: clamped),
                builder: (context, animatedVal, _) {
                  final fillWidth = maxW * animatedVal;
                  return Container(
                    width: fillWidth,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: effectiveGradient,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: hasGlow && animatedVal > 0.05
                          ? [
                              BoxShadow(
                                color: (gradient?.colors.last ?? colors.accentPrimary)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
