import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../pedagogy/widgets/photo_transcription_modal.dart';
import '../../pedagogy/widgets/interactive_function_graph.dart';
import 'problem_correction_screen.dart';

/// Écran complet de l'exercice à étapes « Problème en situation réelle »
class MultiStepProblemScreen extends StatefulWidget {
  const MultiStepProblemScreen({super.key});

  @override
  State<MultiStepProblemScreen> createState() => _MultiStepProblemScreenState();
}

class _MultiStepProblemScreenState extends State<MultiStepProblemScreen> {
  final _answerController = TextEditingController(text: '3x^2 - 18x + 24');

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _showFormulasDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Formulaire de dérivation',
            style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('(xⁿ)\' = n·xⁿ⁻¹',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14)),
            SizedBox(height: 6),
            Text('(u + v)\' = u\' + v\'',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14)),
            SizedBox(height: 6),
            Text('(k·u)\' = k·u\'',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer', style: TextStyle(color: AppColors.tealSuccess)),
          ),
        ],
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Badge Niveau & Toggle chrono
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withAlpha(140),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF14B8A6).withAlpha(120)),
                          ),
                          child: const Text(
                            'NIVEAU 5 • APPROFONDISSEMENT',
                            style: TextStyle(
                              color: Color(0xFFCCFBF1),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withAlpha(20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.timer_off_outlined,
                                  color: Color(0xFF94A3B8), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Chronomètre désactivé',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Titre
                    const Text(
                      'Optimiser un coût de production',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CARTE DU CONTEXTE INDUSTRIEL (Bobines de rouleaux)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withAlpha(220),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                            color: const Color(0xFFF97316).withAlpha(100)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF334155), Color(0xFF0F172A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.factory_rounded,
                                      color: Color(0xFFFBBF24), size: 36),
                                  SizedBox(width: 14),
                                  Icon(Icons.precision_manufacturing_rounded,
                                      color: Color(0xFF38BDF8), size: 36),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Une entreprise fabrique x centaines de rouleaux par jour.',
                                  style: TextStyle(
                                    color: Color(0xFFFB923C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'C(x) = x³ - 9x² + 24x + 100',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'serif',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'x ∈ [0 ; 8]',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontFamily: 'serif',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // STEPPER 4 PHASES : Modéliser, Raisonner, Variations, Conclure
                    _buildPhasesStepper(),

                    const SizedBox(height: 18),

                    // ACCORDÉON DES QUESTIONS
                    _buildQuestionHeader(
                      number: 1,
                      title: 'QUESTION 1 • MODÉLISER',
                      isCompleted: true,
                    ),

                    const SizedBox(height: 10),

                    // QUESTION 2 (ACTIF & DÉPLIÉ)
                    _buildActiveQuestion2(),

                    const SizedBox(height: 10),

                    _buildQuestionHeader(
                      number: 3,
                      title: 'QUESTION 3 • ÉTUDIER LES VARIATIONS',
                      isCompleted: false,
                    ),

                    const SizedBox(height: 10),

                    _buildQuestionHeader(
                      number: 4,
                      title: 'QUESTION 4 • CONCLURE POUR L’ENTREPRISE',
                      isCompleted: false,
                    ),

                    const SizedBox(height: 20),

                    // 4 BOUTONS D'OUTILS : Formulaire, Brouillon, Photo, Indice
                    Row(
                      children: [
                        _buildToolButton(
                          icon: Icons.menu_book_rounded,
                          label: 'FORMULAIRE',
                          onTap: _showFormulasDialog,
                        ),
                        const SizedBox(width: 8),
                        _buildToolButton(
                          icon: Icons.show_chart_rounded,
                          label: 'TRACÉ\nGRAPHIQUE',
                          onTap: () {
                            InteractiveFunctionGraph.showModal(
                              context,
                              expression: _answerController.text.isNotEmpty
                                  ? _answerController.text
                                  : '3x^2 - 18x + 24',
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildToolButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'PHOTOGRAPHIER\nMA FEUILLE',
                          onTap: () {
                            PhotoTranscriptionModal.show(
                              context,
                              onTranscription: (text) {
                                setState(() {
                                  _answerController.text = text;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildToolButton(
                          icon: Icons.lightbulb_outline_rounded,
                          label: 'INDICE\nPROGRESSIF',
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // BOUTON VALIDER CETTE QUESTION
                    ElevatedButton(
                      onPressed: () {
                        // Navigation vers la correction détaillée
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProblemCorrectionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E22CE), // Violet maquette
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'VALIDER CETTE QUESTION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhasesStepper() {
    return Row(
      children: [
        _buildPhaseItem(number: '1', title: 'Modéliser', isCompleted: true),
        _buildPhaseConnector(isCompleted: true),
        _buildPhaseItem(number: '2', title: 'Raisonner', isActive: true),
        _buildPhaseConnector(isCompleted: false),
        _buildPhaseItem(number: '3', title: 'Étudier\nles variations'),
        _buildPhaseConnector(isCompleted: false),
        _buildPhaseItem(number: '4', title: 'Conclure pour\nl’entreprise'),
      ],
    );
  }

  Widget _buildPhaseItem({
    required String number,
    required String title,
    bool isCompleted = false,
    bool isActive = false,
  }) {
    Color color = isCompleted
        ? AppColors.tealSuccess
        : (isActive ? const Color(0xFFA855F7) : const Color(0xFF475569));

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.tealSuccess
                : (isActive ? const Color(0xFF7E22CE) : const Color(0xFF1E293B)),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 65,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              color: isActive ? const Color(0xFFE9D5FF) : const Color(0xFF94A3B8),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseConnector({required bool isCompleted}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 22),
        height: 2,
        color: isCompleted ? AppColors.tealSuccess : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildQuestionHeader({
    required int number,
    required String title,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0D9488).withAlpha(120)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2DD4BF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const Icon(Icons.expand_more_rounded,
              color: Color(0xFF2DD4BF), size: 20),
        ],
      ),
    );
  }

  Widget _buildActiveQuestion2() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withAlpha(160),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF581C87),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'QUESTION 2 SUR 4 • RAISONNER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.expand_less_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Calcule C'(x), factorise-la puis détermine ses zéros.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ma réponse',
                  style: TextStyle(
                    color: Color(0xFFE9D5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      "C'(x) =",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'serif',
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF7E22CE)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF7E22CE)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_note_rounded,
                        color: Color(0xFFC084FC), size: 16),
                    label: const Text(
                      'JUSTIFIER MON RAISONNEMENT',
                      style: TextStyle(
                        color: Color(0xFFC084FC),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF38BDF8), size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
