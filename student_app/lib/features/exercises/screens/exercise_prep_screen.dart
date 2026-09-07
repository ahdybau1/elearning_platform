import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../pedagogy/widgets/photo_transcription_modal.dart';
import 'multi_step_problem_screen.dart';

/// Écran / Modal « Préparer l'exercice »
/// Permet de configurer le chronomètre et le mode de brouillon avant d'entamer l'exercice.
class ExercisePrepScreen extends StatefulWidget {
  final String title;
  final String levelText;
  final String typeText;
  final String description;

  const ExercisePrepScreen({
    super.key,
    this.title = 'Optimisation dans une entreprise',
    this.levelText = 'Niveau 4',
    this.typeText = 'Problème',
    this.description =
        'Une entreprise cherche la quantité produite qui minimise son coût total.',
  });

  @override
  State<ExercisePrepScreen> createState() => _ExercisePrepScreenState();
}

class _ExercisePrepScreenState extends State<ExercisePrepScreen> {
  bool _chronoEnabled = false;
  int _selectedChronoMode = 0; // 0: Sans chrono, 1: 15 min, 2: Personnalisé
  int _selectedDraftMode = 0; // 0: Dans l'app, 1: Photo, 2: Image, 3: Calcul mental

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
            const Center(
              child: Text(
                "PRÉPARER L'EXERCICE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. CARTE HERO ILLUSTRÉE DE L'EXERCICE
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 140,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.3,
                                    child: Center(
                                      child: Icon(
                                        Icons.precision_manufacturing_rounded,
                                        size: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.factory_rounded,
                                          color: Color(0xFF38BDF8), size: 40),
                                      SizedBox(height: 6),
                                      Text(
                                        'Ligne de fabrication & coûts industriels',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
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
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F766E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.levelText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  ${widget.typeText}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.description,
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. CONFIGURATION DU CHRONOMÈTRE
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.timer_outlined,
                                      color: Color(0xFF0D9488), size: 22),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CHRONOMÈTRE',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      Text(
                                        'Facultatif pour cet exercice',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: _chronoEnabled,
                                onChanged: (val) =>
                                    setState(() => _chronoEnabled = val),
                                activeTrackColor: AppColors.tealSuccess,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildChronoOption(
                                index: 0,
                                icon: Icons.timer_off_outlined,
                                title: 'Sans\nchronomètre',
                              ),
                              const SizedBox(width: 8),
                              _buildChronoOption(
                                index: 1,
                                icon: Icons.access_time_rounded,
                                title: '15 minutes',
                              ),
                              const SizedBox(width: 8),
                              _buildChronoOption(
                                index: 2,
                                icon: Icons.edit_calendar_rounded,
                                title: 'Temps\npersonnalisé',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline_rounded,
                                    color: Color(0xFF0D9488), size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Le chronomètre devient obligatoire uniquement en mode examen.',
                                    style: TextStyle(
                                      color: Color(0xFF115E59),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. MON BROUILLON
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.edit_note_rounded,
                                  color: Color(0xFF7E22CE), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'MON BROUILLON',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.4,
                            children: [
                              _buildDraftOption(
                                index: 0,
                                icon: Icons.edit_rounded,
                                title: "Écrire dans\nl'application",
                              ),
                              _buildDraftOption(
                                index: 1,
                                icon: Icons.camera_alt_outlined,
                                title: 'Photographier\nma feuille',
                              ),
                              _buildDraftOption(
                                index: 2,
                                icon: Icons.image_outlined,
                                title: 'Importer une\nimage',
                              ),
                              _buildDraftOption(
                                index: 3,
                                icon: Icons.psychology_outlined,
                                title: 'Calcul mental\nuniquement',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline_rounded,
                                    color: Color(0xFF9333EA), size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tu pourras modifier ce choix pendant l’exercice.',
                                    style: TextStyle(
                                      color: Color(0xFF6B21A8),
                                      fontSize: 11,
                                    ),
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

            // Bouton Commencer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const MultiStepProblemScreen(),
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'COMMENCER',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChronoOption({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedChronoMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedChronoMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.tealSuccess
                  : const Color(0xFFCBD5E1),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.tealSuccess
                    : const Color(0xFF64748B),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF334155),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftOption({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedDraftMode == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDraftMode = index);
        if (index == 1 || index == 2) {
          PhotoTranscriptionModal.show(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9333EA)
                : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF9333EA)
                  : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7E22CE)
                    : const Color(0xFF334155),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
