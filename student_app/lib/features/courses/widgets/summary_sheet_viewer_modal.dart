import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/summary_sheet_registry.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../ai_tutor/widgets/contextual_ai_agent_sheet.dart';

/// Modal interactive plein écran permettant de consulter une Fiche de Synthèse
/// en deux modes complémentaires :
/// 1. Vue Visuelle HD (Zoom tactile libre via [InteractiveViewer])
/// 2. Vue Cours Structuré (Formules LaTeX nettes, définitions et astuces d'examen)
class SummarySheetViewerModal extends StatefulWidget {
  final SummarySheet sheet;

  const SummarySheetViewerModal({
    super.key,
    required this.sheet,
  });

  /// Méthode d'ouverture pratique en modal bottom sheet ou dialogue plein écran
  static Future<void> show(BuildContext context, SummarySheet sheet) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SummarySheetViewerModal(sheet: sheet),
      ),
    );
  }

  @override
  State<SummarySheetViewerModal> createState() => _SummarySheetViewerModalState();
}

class _SummarySheetViewerModalState extends State<SummarySheetViewerModal> {
  final TransformationController _transformationController =
      TransformationController();
  int _selectedViewMode = 0; // 0: Image HD avec Zoom, 1: Contenu Structuré

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sheet.title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${sheet.subject} • ${sheet.level}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primaryCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedViewMode == 0)
            IconButton(
              icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white70),
              tooltip: 'Réinitialiser le zoom',
              onPressed: _resetZoom,
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_added_outlined, color: AppColors.tealSuccess),
            tooltip: 'Fiche enregistrée pour révisions hors-ligne',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0F172A),
                  behavior: SnackBarBehavior.floating,
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: AppColors.tealSuccess, size: 20),
                      SizedBox(width: 10),
                      Text('Fiche de synthèse disponible hors-ligne.'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de bascule Mode Fiche Visuelle / Mode Cours Structuré
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF0B1120),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: AppRadius.radiusFull,
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        index: 0,
                        icon: Icons.image_outlined,
                        label: 'Fiche Visuelle HD (Zoom)',
                      ),
                    ),
                    Expanded(
                      child: _buildModeTab(
                        index: 1,
                        icon: Icons.menu_book_rounded,
                        label: 'Formules & Définitions',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Corps principal selon le mode sélectionné
            Expanded(
              child: _selectedViewMode == 0
                  ? _buildZoomableImageView(sheet)
                  : _buildStructuredContentView(sheet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedViewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedViewMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: AppRadius.radiusFull,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vue 1 : Image Haute Définition avec Zoom Tactile
  Widget _buildZoomableImageView(SummarySheet sheet) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.8,
              maxScale: 4.5,
              boundaryMargin: const EdgeInsets.all(40),
              child: Image.asset(
                sheet.imageAssetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'Image en cours de chargement...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.pinch_rounded, color: AppColors.primaryCyan, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Pincez pour zoomer • Déplacez pour explorer',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vue 2 : Contenu Structuré & Formules LaTeX
  Widget _buildStructuredContentView(SummarySheet sheet) {
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: sheet.sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final section = sheet.sections[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: const Color(0xFF2B3754)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre de section
              Text(
                section.title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Encadré formule mathématique / physique avec rendu KaTeX vectoriel
              MathFormulaView(
                formulaLatex: section.formulaLatex,
                fontSize: 15,
                label: '${sheet.subject.toUpperCase()} • FORMULE OFFICIELLE',
              ),

              const SizedBox(height: 12),

              // Explication
              Text(
                section.explanation,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE2E8F0),
                ),
              ),

              if (section.bulletPoints.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final point in section.bulletPoints) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFFCBD5E1),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // Astuce / Remarque d'examen
              if (section.tip != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withAlpha(80),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_rounded,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          section.tip!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFFDE68A),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2B3754), height: 1),
              const SizedBox(height: 12),

              // Barre d'actions Agents IA EDLEARN (Tuteur Socratique, Pièges, Exercices)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryCyan,
                        side: const BorderSide(color: AppColors.primaryCyan, width: 1.1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      onPressed: () {
                        ContextualAiAgentSheet.show(
                          context,
                          topicTitle: section.title,
                          subject: sheet.subject,
                          formulaLatex: section.formulaLatex,
                          initialMode: 'tutor',
                        );
                      },
                      icon: const Icon(Icons.psychology_rounded, size: 15),
                      label: const Text(
                        'Tuteur Socratique',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.amberHighlight,
                        side: const BorderSide(color: AppColors.amberHighlight, width: 1.1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      onPressed: () {
                        ContextualAiAgentSheet.show(
                          context,
                          topicTitle: section.title,
                          subject: sheet.subject,
                          formulaLatex: section.formulaLatex,
                          initialMode: 'diagnostic',
                        );
                      },
                      icon: const Icon(Icons.rule_rounded, size: 15),
                      label: const Text(
                        'Pièges du Bac',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealSuccess,
                        foregroundColor: const Color(0xFF0A0E1A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      onPressed: () {
                        ContextualAiAgentSheet.show(
                          context,
                          topicTitle: section.title,
                          subject: sheet.subject,
                          formulaLatex: section.formulaLatex,
                          initialMode: 'exercise',
                        );
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text(
                        'S\'entraîner',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
