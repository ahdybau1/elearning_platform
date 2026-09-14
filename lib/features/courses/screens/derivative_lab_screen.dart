import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../pedagogy/widgets/interactive_function_graph.dart';

/// Écran complet de l'Activité Interactive « Observe la dérivée »
/// Permet à l'élève de manipuler le point A sur la courbe, d'observer
/// la pente de la tangente f'(x) en direct et de valider ses observations.
class DerivativeLabScreen extends StatefulWidget {
  final int currentStep;
  final int totalSteps;

  const DerivativeLabScreen({
    super.key,
    this.currentStep = 3,
    this.totalSteps = 6,
  });

  @override
  State<DerivativeLabScreen> createState() => _DerivativeLabScreenState();
}

class _DerivativeLabScreenState extends State<DerivativeLabScreen> {
  double _currentX = 2.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128), // Fond bleu nuit de la maquette
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MATHÉMATIQUES • TERMINALE C & D',
          style: TextStyle(
            color: AppColors.tealSuccess,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Badge Activité Interactive
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8).withAlpha(160),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFA855F7).withAlpha(100),
                          ),
                        ),
                        child: const Text(
                          'ACTIVITÉ INTERACTIVE',
                          style: TextStyle(
                            color: Color(0xFFE9D5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Titre
                    const Text(
                      'Observe la dérivée',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Consigne
                    const Text(
                      'Déplace le point A sur la courbe.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Graphe interactif avec Tangente en temps réel
                    InteractiveFunctionGraph(
                      functionSpec: MathFunctionSpec.defaultCubic,
                      initialX: _currentX,
                      onXChanged: (val) {
                        setState(() => _currentX = val);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Indicateur de progression (Étape 3 sur 6)
                    Row(
                      children: [
                        Text(
                          'ÉTAPE ${widget.currentStep} SUR ${widget.totalSteps}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildStepperIndicator(
                            current: widget.currentStep,
                            total: widget.totalSteps,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Barre de boutons inférieure (< Précédent | Valider mon observation)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border(
                  top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('PRÉCÉDENT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // The activity is opened from the reader: keep its selected
                        // lesson and scroll position instead of fabricating a chapter.
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'REVENIR AU COURS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperIndicator({required int current, required int total}) {
    return Row(
      children: List.generate(total * 2 - 1, (index) {
        if (index.isOdd) {
          // Ligne de liaison
          final stepIndex = (index ~/ 2) + 1;
          final isCompleted = stepIndex < current;
          return Expanded(
            child: Container(
              height: 2.5,
              color: isCompleted
                  ? AppColors.tealSuccess
                  : const Color(0xFF334155),
            ),
          );
        } else {
          // Point ou cercle
          final stepIndex = (index ~/ 2) + 1;
          final isCompleted = stepIndex < current;
          final isCurrent = stepIndex == current;

          return Container(
            width: isCurrent ? 12 : 8,
            height: isCurrent ? 12 : 8,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.tealSuccess
                  : (isCurrent ? Colors.white : const Color(0xFF475569)),
              shape: BoxShape.circle,
              border: isCurrent
                  ? Border.all(color: AppColors.tealSuccess, width: 2.5)
                  : null,
            ),
          );
        }
      }),
    );
  }
}
