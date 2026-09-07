import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'lesson_reader_screen.dart';

/// Écran immersif d'introduction d'un chapitre :
/// Contextualisation historique (Pierre de Fermat, Newton, Leibniz),
/// Application industrielle contemporaine, Grande question et Compétences cibles.
class ChapterIntroScreen extends StatelessWidget {
  final String subjectName;
  final String gradeName;
  final String chapterTitle;

  const ChapterIntroScreen({
    super.key,
    this.subjectName = 'MATHÉMATIQUES',
    this.gradeName = 'TERMINALE C & D',
    this.chapterTitle = 'Pourquoi a-t-on inventé la dérivée ?',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128), // Bleu nuit immersif de la maquette
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '$subjectName • $gradeName',
          style: const TextStyle(
            color: AppColors.tealSuccess,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de catégorie
              const Center(
                child: Text(
                  'INTRODUCTION DU CHAPITRE',
                  style: TextStyle(
                    color: Color(0xFF818CF8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Titre marquant
              Text(
                chapterTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  width: 50,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 1. BLOC HISTORIQUE : UNE IDÉE NÉE D'UN PROBLÈME
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withAlpha(190),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFFD97706).withAlpha(120)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Illustration historique (Fermat / Calcul différentiel)
                    Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF374151), Color(0xFF111827)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.25,
                              child: CustomPaint(
                                painter: _GeometryBackgroundPainter(),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.history_edu_rounded,
                                    size: 48, color: Color(0xFFFBBF24)),
                                SizedBox(height: 8),
                                Text(
                                  'Pierre de Fermat • Newton & Leibniz',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "UNE IDÉE NÉE D'UN PROBLÈME",
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Au XVIIᵉ siècle, Pierre de Fermat cherche une méthode pour déterminer les tangentes et les maximums. Newton et Leibniz développent ensuite le calcul différentiel.",
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. BLOC MONDE RÉEL : D'HIER À AUJOURD'HUI
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withAlpha(190),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.tealSuccess.withAlpha(120)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 140,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.factory_rounded,
                                size: 40, color: AppColors.tealSuccess),
                            SizedBox(width: 16),
                            Icon(Icons.query_stats_rounded,
                                size: 40, color: Color(0xFF38BDF8)),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "D'HIER À AUJOURD'HUI",
                            style: TextStyle(
                              color: AppColors.tealSuccess,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Dans une entreprise, la dérivée aide à réduire les coûts, optimiser la production et prévoir une évolution.",
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. LA GRANDE QUESTION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B).withAlpha(180),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFF6366F1).withAlpha(120)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4338CA),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LA GRANDE QUESTION',
                            style: TextStyle(
                              color: Color(0xFFA5B4FC),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Comment mesurer une variation instantanée et trouver la meilleure valeur possible ?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. PRÉREQUIS
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2B48).withAlpha(160),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFF0284C7).withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded,
                        color: Color(0xFF38BDF8), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'PRÉREQUIS',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Fonctions • Équations • Signe d’une expression • Lecture graphique',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 5. À LA FIN DU CHAPITRE, TU SAURAS
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF311042).withAlpha(160),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFF9333EA).withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.track_changes_rounded,
                        color: Color(0xFFC084FC), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'À LA FIN DU CHAPITRE, TU SAURAS',
                            style: TextStyle(
                              color: Color(0xFFC084FC),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Calculer • Interpréter • Modéliser • Optimiser',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Bouton Commencer la première leçon
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LessonReaderScreen(
                        chapterId: 'chap_derivation',
                        chapterTitle: 'Dérivation et étude des fonctions',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealSuccess,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'COMMENCER LA PREMIÈRE LEÇON',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeometryBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Tracé d'un cercle et d'un triangle géométrique inspiré des traités de Fermat
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 45, paint);
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.3),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.7),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
