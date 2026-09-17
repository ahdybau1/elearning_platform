import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/student_theme.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';

/// Bandeau de rétroaction pédagogique et de célébration pour les exercices.
class ExerciseFeedbackBanner extends StatelessWidget {
  final bool isCorrect;
  final String title;
  final String message;
  final int xpEarned;
  final VoidCallback onContinue;
  final VoidCallback? onAskTutor;
  final String continueLabel;

  const ExerciseFeedbackBanner({
    super.key,
    required this.isCorrect,
    required this.title,
    required this.message,
    this.xpEarned = 0,
    required this.onContinue,
    this.onAskTutor,
    this.continueLabel = 'Continuer',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = isCorrect ? AppColors.emeraldSuccess : AppColors.amberWarning;
    final gradient = isCorrect ? AppColors.emeraldGradient : AppColors.amberGradient;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: accentColor.withValues(alpha: 0.6), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check_rounded : Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isCorrect && xpEarned > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: AppColors.goldPremium),
                          const SizedBox(width: 4),
                          Text(
                            '+$xpEarned XP gagnés',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.goldPremium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.6),
                borderRadius: AppRadius.radiusMedium,
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (onAskTutor != null && !isCorrect) ...[
                OutlinedButton.icon(
                  onPressed: onAskTutor,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Comprendre avec l\'IA'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                    side: BorderSide(color: AppColors.cyanAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: AppRadius.radiusMedium,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusMedium,
                      ),
                    ),
                    child: Text(
                      continueLabel,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
