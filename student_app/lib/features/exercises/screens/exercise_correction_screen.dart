import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../ai_tutor/widgets/contextual_ai_agent_sheet.dart';
import '../../pedagogy/widgets/variation_table_interactive.dart';

/// Écran de Correction et de Remédiation après l'exercice du Tableau de Variations
class ExerciseCorrectionScreen extends StatelessWidget {
  final int score;
  final int maxScore;
  final int xpGained;

  const ExerciseCorrectionScreen({
    super.key,
    this.score = 7,
    this.maxScore = 10,
    this.xpGained = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bannière verte de validation + badge XP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'CORRECTION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Bonne progression ! ✨',
                                  style: TextStyle(
                                    color: AppColors.tealSuccess,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Badge XP
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14532D),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF22C55E)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFBBF24), size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '+$xpGained XP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Cartes Score & Compétence
                    Row(
                      children: [
                        // Score
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Score :',
                                  style: TextStyle(
                                      color: Color(0xFF64748B), fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$score',
                                      style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      ' / $maxScore',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: score / maxScore,
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF16A34A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Compétence
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: const Color(0xFFE9D5FF)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.track_changes_rounded,
                                        color: Color(0xFF9333EA), size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Compétence :',
                                      style: TextStyle(
                                        color: Color(0xFF7E22CE),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'étudier les variations',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Maîtrise actuelle : 72 %',
                                  style: TextStyle(
                                    color: Color(0xFF6B21A8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    value: 0.72,
                                    minHeight: 5,
                                    backgroundColor: Color(0xFFE9D5FF),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF9333EA)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Rappel de l'énoncé
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  color: Color(0xFF2563EB), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Exercice',
                                style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Soit f(x) = x³ - 3x² + 1.\nOn donne f'(x) = 3x(x - 2).",
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 13,
                              fontFamily: 'serif',
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // TABLEAU CORRIGÉ
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'TABLEAU CORRIGÉ',
                                style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          VariationTableInteractive(
                            isInteractive: false,
                            initialData:
                                VariationTableData.defaultCubicCorrection,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CARTE TON ERREUR (avec schéma de l'intervalle [0 ; 2])
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEA580C), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'TON ERREUR',
                                style: TextStyle(
                                  color: Color(0xFFC2410C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const InlineLatexText(
                            r"Tu as indiqué que la fonction était croissante entre 0 et 2." "\n" r"Or $f'(x) = 3x(x - 2)$ est négative sur cet intervalle.",
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Schéma de droite numérique
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildNumberLineSegment(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),
                          Row(
                            children: const [
                              Icon(Icons.arrow_forward_rounded,
                                  color: Color(0xFFEA580C), size: 16),
                              SizedBox(width: 6),
                              Expanded(
                                child: InlineLatexText(
                                  r"Entre 0 et 2, $f'(x)$ est négative : la fonction est donc décroissante.",
                                  style: TextStyle(
                                    color: Color(0xFFC2410C),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Bouton Déclencheur DiagnosticAgent / MisconceptionAgent
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ContextualAiAgentSheet.show(
                                  context,
                                  topicTitle: 'Tableau de variations & Racines',
                                  subject: 'Mathématiques',
                                  formulaLatex: "Erreur fréquente sur f'(x) = 3x(x - 2) : signe négatif sur ]0, 2[.",
                                  initialMode: 'diagnostic',
                                );
                              },
                              icon: const Icon(Icons.psychology_alt_rounded, size: 16, color: Color(0xFFC2410C)),
                              label: const Text(
                                "Analyser mon erreur avec l'IA Diagnostic",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFED7AA), width: 1.2),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.radiusSmall,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CARTE À RETENIR
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.lightbulb_outline_rounded,
                                  color: Color(0xFF9333EA), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'À RETENIR',
                                style: TextStyle(
                                  color: Color(0xFF7E22CE),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: InlineLatexText(
                                  r"Le signe de $f'$ indique le sens de variation de $f$.",
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Math.tex(r"f' > 0", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                        const Text(" → ↗ ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                        Math.tex(r"f \text{ croissante}", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Math.tex(r"f' < 0", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                                        const Text(" → ↘ ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                                        Math.tex(r"f \text{ décroissante}", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 11, color: Color(0xFFEA580C))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Math.tex(r"f' = 0", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                        const Text(" → — ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                        Math.tex(r"\text{point critique}", mathStyle: MathStyle.text, textStyle: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Célébration
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.emoji_events_rounded,
                              color: Color(0xFF16A34A), size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Belle analyse !',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Tu maîtrises de mieux en mieux les tableaux de variations.',
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Barre d'actions inférieure (Revoir explication | Réessayer | Exercice similaire)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border(
                  top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.menu_book_rounded, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "REVOIR\nL'EXPLICATION",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'RÉESSAYER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E22CE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nouvel exercice ciblé chargé !'),
                            backgroundColor: AppColors.tealSuccess,
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'EXERCICE\nSIMILAIRE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
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

  Widget _buildNumberLineSegment() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('0',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 45),
            const Text('2',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 2,
              color: const Color(0xFF64748B),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEA580C), width: 2),
                color: Colors.white,
              ),
            ),
            Container(
              width: 45,
              height: 3,
              color: const Color(0xFFEA580C),
              child: const Center(
                child: Text(
                  '—',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEA580C), width: 2),
                color: Colors.white,
              ),
            ),
            Container(
              width: 18,
              height: 2,
              color: const Color(0xFF64748B),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          "f'(x) < 0",
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFEA580C),
            fontFamily: 'serif',
          ),
        ),
      ],
    );
  }
}
