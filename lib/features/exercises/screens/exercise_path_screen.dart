import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'variation_table_exercise_screen.dart';

/// Écran de parcours adaptatif en 6 niveaux du rappel au niveau BAC
class ExercisePathScreen extends StatelessWidget {
  final String subjectName;
  final String gradeName;
  final int currentLevel;

  const ExercisePathScreen({
    super.key,
    this.subjectName = 'MATHÉMATIQUES',
    this.gradeName = 'TERMINALE C & D',
    this.currentLevel = 3,
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Titre & Badge Niveau actuel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "PARCOURS D'EXERCICES",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Du rappel au niveau BAC',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        // Badge Niveau actuel
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF6366F1).withAlpha(120)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bar_chart_rounded,
                                  color: Color(0xFF38BDF8), size: 18),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ton niveau actuel :',
                                    style: TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 9),
                                  ),
                                  Text(
                                    '$currentLevel',
                                    style: const TextStyle(
                                      color: Color(0xFFC084FC),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // LISTE DES NIVEAUX DE COMPÉTENCE (1 À 6)
                    _buildLevelNode(
                      context: context,
                      levelNumber: 1,
                      badgeText: 'PRÉREQUIS',
                      title: 'Calcul algébrique et lecture graphique',
                      subtitle:
                          'Puissances, fractions, équations, lecture de courbes.',
                      progressText: '12/12',
                      progressRatio: 1.0,
                      isCompleted: true,
                      isActive: false,
                      isLocked: false,
                      icon: Icons.calculate_outlined,
                    ),
                    _buildTimelineConnector(isCompleted: true),

                    _buildLevelNode(
                      context: context,
                      levelNumber: 2,
                      badgeText: 'APPLICATION DIRECTE',
                      title: 'Dériver avec les formules usuelles',
                      subtitle: 'Somme, produit, quotient, composée.',
                      progressText: '18/18',
                      progressRatio: 1.0,
                      isCompleted: true,
                      isActive: false,
                      isLocked: false,
                      icon: Icons.functions_rounded,
                    ),
                    _buildTimelineConnector(isCompleted: true),

                    _buildLevelNode(
                      context: context,
                      levelNumber: 3,
                      badgeText: 'RAISONNEMENT',
                      title: "Relier signe de f' et variations",
                      subtitle: 'Tableau de signes, variations, extremums.',
                      progressText: '8/15',
                      progressRatio: 8 / 15,
                      isCompleted: false,
                      isActive: true,
                      isLocked: false,
                      icon: Icons.show_chart_rounded,
                    ),
                    _buildTimelineConnector(isCompleted: false),

                    _buildLevelNode(
                      context: context,
                      levelNumber: 4,
                      badgeText: 'PROBLÈME',
                      title: 'Optimisation dans une situation réelle',
                      subtitle: 'Aire, volume, coût, profit, modélisation.',
                      progressText: '0/16',
                      progressRatio: 0.0,
                      isCompleted: false,
                      isActive: false,
                      isLocked: true,
                      unlockInfo: 'Débloque à 12/15',
                      icon: Icons.factory_outlined,
                    ),
                    _buildTimelineConnector(isCompleted: false),

                    _buildLevelNode(
                      context: context,
                      levelNumber: 5,
                      badgeText: 'APPROFONDISSEMENT',
                      title: 'Paramètre, preuve et justification',
                      subtitle: 'Étude selon un paramètre, inégalités, preuve.',
                      progressText: '0/18',
                      progressRatio: 0.0,
                      isCompleted: false,
                      isActive: false,
                      isLocked: true,
                      unlockInfo: 'Débloque à 14/16',
                      icon: Icons.auto_awesome_outlined,
                    ),
                    _buildTimelineConnector(isCompleted: false),

                    _buildLevelNode(
                      context: context,
                      levelNumber: 6,
                      badgeText: 'TYPE BAC',
                      title: 'Problème complet, autonome et chronométrable',
                      subtitle: 'Étude, optimisation, discussion, rédaction.',
                      progressText: '0/20',
                      progressRatio: 0.0,
                      isCompleted: false,
                      isActive: false,
                      isLocked: true,
                      unlockInfo: 'Débloque à 16/18',
                      isGold: true,
                      icon: Icons.workspace_premium_outlined,
                    ),

                    const SizedBox(height: 20),

                    // Bannière d'info adaptative
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                            color: const Color(0xFF0284C7).withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFF38BDF8), size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Le niveau suivant s'adapte à tes réponses.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Plus tu réussis, plus les exercices sont poussés.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.insights_rounded,
                              color: Color(0xFF38BDF8), size: 26),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Barre d'actions en bas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withAlpha(20),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFFFBBF24), size: 18),
                    label: const Text(
                      'ESSAYER UN DÉFI\nOptionnel • Plus corsé',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const VariationTableExerciseScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E22CE), // Violet actif
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_arrow_rounded, size: 22),
                          SizedBox(width: 6),
                          Text(
                            'CHOISIR CE NIVEAU\nNiveau 3 • Raisonnement',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12),
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

  Widget _buildLevelNode({
    required BuildContext context,
    required int levelNumber,
    required String badgeText,
    required String title,
    required String subtitle,
    required String progressText,
    required double progressRatio,
    required bool isCompleted,
    required bool isActive,
    required bool isLocked,
    String? unlockInfo,
    bool isGold = false,
    required IconData icon,
  }) {
    Color nodeColor;
    if (isCompleted) {
      nodeColor = AppColors.tealSuccess;
    } else if (isActive) {
      nodeColor = const Color(0xFF9333EA); // Violet éclatant
    } else if (isGold) {
      nodeColor = const Color(0xFFF59E0B);
    } else {
      nodeColor = const Color(0xFF475569);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge circulaire du niveau
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: isActive ? nodeColor : (isCompleted ? nodeColor : const Color(0xFF1E293B)),
            shape: BoxShape.circle,
            border: Border.all(
              color: nodeColor,
              width: isActive ? 3 : 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: nodeColor.withAlpha(120),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : (isLocked
                    ? const Icon(Icons.lock_rounded,
                        color: Color(0xFF94A3B8), size: 16)
                    : Text(
                        '$levelNumber',
                        style: TextStyle(
                          color: isActive ? Colors.white : nodeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 14),

        // Carte de détails du niveau
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFAF5FF)
                  : (isLocked ? const Color(0xFFF1F5F9).withAlpha(220) : Colors.white),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFA855F7)
                    : (isLocked ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
                width: isActive ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NIVEAU $levelNumber • $badgeText',
                      style: TextStyle(
                        color: isLocked
                            ? const Color(0xFF64748B)
                            : (isActive ? const Color(0xFF7E22CE) : const Color(0xFF0F766E)),
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Maîtrisé',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isLocked && unlockInfo != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded,
                              color: Color(0xFF64748B), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            unlockInfo,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted
                                ? AppColors.tealSuccess
                                : const Color(0xFF9333EA),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      progressText,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector({required bool isCompleted}) {
    return Container(
      margin: const EdgeInsets.only(left: 17),
      height: 20,
      width: 2.5,
      color: isCompleted
          ? AppColors.tealSuccess
          : const Color(0xFF334155),
    );
  }
}
