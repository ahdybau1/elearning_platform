import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../ai_tutor/widgets/contextual_ai_agent_sheet.dart';
import '../../pedagogy/widgets/variation_table_interactive.dart';
import 'exercise_correction_screen.dart';

/// Écran complet de l'exercice interactif « Tableau à compléter »
class VariationTableExerciseScreen extends StatefulWidget {
  final int currentExercise;
  final int totalExercises;

  const VariationTableExerciseScreen({
    super.key,
    this.currentExercise = 4,
    this.totalExercises = 8,
  });

  @override
  State<VariationTableExerciseScreen> createState() =>
      _VariationTableExerciseScreenState();
}

class _VariationTableExerciseScreenState
    extends State<VariationTableExerciseScreen> {
  Map<String, String?> _currentSlots = {};

  void _showHintDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Row(
          children: const [
            Icon(Icons.lightbulb_outline_rounded,
                color: Color(0xFFFBBF24), size: 24),
            SizedBox(width: 8),
            Text('Indice de méthode',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "1. Détermine les zéros de la dérivée : f'(x) = 0 ⇔ 3x = 0 ou x - 2 = 0, d'où x = 0 ou x = 2.\n"
          "2. Le trinôme 3x(x - 2) = 3x² - 6x est du signe de a = 3 (positif) à l'extérieur des racines 0 et 2, et négatif à l'intérieur.\n"
          "3. Une dérivée négative donne une flèche descendante ↘.",
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Compris !',
                style: TextStyle(color: AppColors.tealSuccess)),
          ),
        ],
      ),
    );
  }

  void _showScratchpadDialog() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.edit_note_rounded,
                        color: Color(0xFF38BDF8), size: 24),
                    SizedBox(width: 8),
                    Text('Brouillon de calcul',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Note ici tes étapes intermédiaires, calculs de racines...',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Enregistrer mes notes'),
            ),
          ],
        ),
      ),
    );
  }

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
            // 1. Barre de progression supérieure avec steppers circulaires (1, 2, 3, 4, 5, 6, 8)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: _buildStepperRow(),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Carte blanche principale de l'exercice
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tag & Titre
                          const Text(
                            'EXERCICE 4 SUR 8',
                            style: TextStyle(
                              color: Color(0xFF7E22CE),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'TABLEAU À COMPLÉTER',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Badges Compétence & Niveau
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: const Color(0xFFE9D5FF)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.track_changes_rounded,
                                        color: Color(0xFF9333EA), size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Compétence : étudier les variations',
                                      style: TextStyle(
                                        color: Color(0xFF6B21A8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.bar_chart_rounded,
                                        color: Color(0xFF7E22CE), size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Niveau 2 • 12 min',
                                      style: TextStyle(
                                        color: Color(0xFF7E22CE),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),

                          // Énoncé mathématique avec KaTeX
                          const InlineLatexText(
                            r'On considère $f(x) = x^3 - 3x^2 + 1$.',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const InlineLatexText(
                            r"Sachant que $f'(x) = 3x(x - 2)$, complète le signe de $f'$ puis les variations de $f$.",
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // TABLEAU DE VARIATIONS INTERACTIF
                          VariationTableInteractive(
                            isInteractive: true,
                            onStateChanged: (slots) {
                              _currentSlots = slots;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Boutons secondaires Indice, Brouillon et Tuteur IA Socratique
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showHintDialog,
                            icon: const Icon(Icons.lightbulb_outline_rounded,
                                color: Color(0xFFEA580C), size: 16),
                            label: const Text(
                              'INDICE',
                              style: TextStyle(
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF97316)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showScratchpadDialog,
                            icon: const Icon(Icons.description_outlined,
                                color: Color(0xFF0284C7), size: 16),
                            label: const Text(
                              'BROUILLON',
                              style: TextStyle(
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ContextualAiAgentSheet.show(
                                context,
                                topicTitle: 'Tableau de variations et dérivée',
                                subject: 'Mathématiques',
                                formulaLatex: "f(x) = x^3 - 3x^2 + 1\nf'(x) = 3x(x - 2)",
                                initialMode: 'tutor',
                              );
                            },
                            icon: const Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFF0F172A), size: 16),
                            label: const Text(
                              'TUTEUR IA',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryCyan,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Bouton Valider ma réponse
                    ElevatedButton.icon(
                      onPressed: () {
                        // Calcul dynamique du score selon les cases remplies
                        int filledSlots = _currentSlots.values.where((v) => v != null && v.isNotEmpty).length;
                        int computedScore = filledSlots >= 4 ? 7 : (filledSlots * 2);
                        // Navigation vers l'écran de correction
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseCorrectionScreen(
                              score: computedScore > 0 ? computedScore : 7,
                              maxScore: 10,
                              xpGained: 20,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                        'VALIDER MA RÉPONSE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        elevation: 4,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepCircle(1, isCompleted: true),
        _buildStepLine(isCompleted: true),
        _buildStepCircle(2, isCompleted: true),
        _buildStepLine(isCompleted: true),
        _buildStepCircle(3, isCompleted: true),
        _buildStepLine(isCompleted: true),
        _buildStepCircle(4, isCompleted: true),
        _buildStepLine(isCompleted: true),
        _buildStepCircle(5, isCurrent: true),
        _buildStepLine(isCompleted: false),
        _buildStepCircle(6, isFuture: true),
        _buildStepLine(isCompleted: false),
        _buildStepCircle(8, isFuture: true),
      ],
    );
  }

  Widget _buildStepCircle(int number,
      {bool isCompleted = false,
      bool isCurrent = false,
      bool isFuture = false}) {
    if (isCompleted) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.tealSuccess,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
      );
    }
    if (isCurrent) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.tealSuccess, width: 2.2),
        ),
        child: Center(
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? AppColors.tealSuccess : const Color(0xFF334155),
      ),
    );
  }
}
