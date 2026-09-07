import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';

/// Écran de correction détaillée avec gestion de l'erreur propagée et remédiation ciblée
class ProblemCorrectionScreen extends StatefulWidget {
  final int score;
  final int totalScore;

  const ProblemCorrectionScreen({
    super.key,
    this.score = 14,
    this.totalScore = 20,
  });

  @override
  State<ProblemCorrectionScreen> createState() =>
      _ProblemCorrectionScreenState();
}

class _ProblemCorrectionScreenState extends State<ProblemCorrectionScreen> {
  int _expandedQuestion = 2;

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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête
                    const Center(
                      child: Text(
                        'CORRECTION DÉTAILLÉE',
                        style: TextStyle(
                          color: Color(0xFFA5B4FC),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Optimiser un coût de production',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Carte du Score global (14 / 20)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppColors.tealSuccess.withAlpha(120),
                              width: 1.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.score}',
                              style: const TextStyle(
                                color: AppColors.tealSuccess,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' / ${widget.totalScore}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Bon raisonnement, calcul à consolider',
                        style: TextStyle(
                          color: AppColors.tealSuccess,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // LISTE DES QUESTIONS EN ACCORDÉON
                    _buildQuestionItem(
                      number: 1,
                      title: 'Modéliser',
                      scoreText: '4 / 4',
                      isSuccess: true,
                    ),

                    const SizedBox(height: 10),

                    // QUESTION 2 (DÉPLIÉE PAR DÉFAUT AVEC ANALYSE POUSSÉE)
                    _buildQuestion2Detailed(),

                    const SizedBox(height: 10),

                    _buildQuestionItem(
                      number: 3,
                      title: 'Étudier les variations',
                      scoreText: '4 / 6',
                      isSuccess: false,
                    ),

                    const SizedBox(height: 10),

                    _buildQuestionItem(
                      number: 4,
                      title: 'Conclure pour l’entreprise',
                      scoreText: '3 / 5',
                      isSuccess: false,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // BARRE INFÉRIEURE : EXERCICE CIBLÉ | CORRIGER MA COPIE | CONTINUER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Génération d’un exercice ciblé de factorisation...'),
                          backgroundColor: Color(0xFF6366F1),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.menu_book_rounded, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'EXERCICE CIBLÉ',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.edit_note_rounded, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'CORRIGER\nMA COPIE',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.track_changes_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'CONTINUER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
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

  Widget _buildQuestionItem({
    required int number,
    required String title,
    required String scoreText,
    required bool isSuccess,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ListTile(
        onTap: () => setState(() => _expandedQuestion = number),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              scoreText,
              style: TextStyle(
                color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              _expandedQuestion == number
                  ? Icons.expand_less_rounded
                  : (isSuccess
                      ? Icons.check_circle_outline_rounded
                      : Icons.expand_more_rounded),
              color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion2Detailed() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête Question 2
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFFFF7ED),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dériver et factoriser',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Text(
                  '3 / 5',
                  style: TextStyle(
                    color: Color(0xFFEA580C),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_less_rounded,
                    color: Color(0xFFEA580C), size: 22),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Comparaison Ta Réponse VS Réponse Attendue
                Row(
                  children: [
                    // Ta réponse
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'TA RÉPONSE',
                              style: TextStyle(
                                color: Color(0xFFBE123C),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "C'(x) = 3x² - 18x + 24",
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // VS
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    // Réponse attendue
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'RÉPONSE ATTENDUE',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "C'(x) = 3(x - 2)(x - 4)",
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 1. CE QUI EST RÉUSSI (vert)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CE QUI EST RÉUSSI',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'La dérivée développée est correcte.',
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

                const SizedBox(height: 8),

                // 2. À CORRIGER (orange)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.error_outline_rounded,
                          color: Color(0xFFEA580C), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'À CORRIGER',
                              style: TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'La factorisation est incomplète, ce qui entraîne une erreur dans le tableau de signes.',
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

                const SizedBox(height: 8),

                // 3. ERREUR PROPAGÉE PRISE EN COMPTE (violet)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.auto_graph_rounded,
                          color: Color(0xFF9333EA), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ERREUR PROPAGÉE PRISE EN COMPTE',
                              style: TextStyle(
                                color: Color(0xFF7E22CE),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ton raisonnement de la question 3 reste cohérent avec ton résultat précédent : une partie des points est conservée.',
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

                const SizedBox(height: 10),

                // 4. REMÉDIATION CONSEILLÉE
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.menu_book_rounded,
                              color: Color(0xFF475569), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'REMÉDIATION CONSEILLÉE',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Factoriser un trinôme avant de reprendre la conclusion.',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fiche méthode : Factorisation du trinôme affichée.'),
                                backgroundColor: Color(0xFF6366F1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.school_outlined, size: 16),
                          label: const Text('REVOIR LA MÉTHODE'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(color: Color(0xFF818CF8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
        ],
      ),
    );
  }
}
