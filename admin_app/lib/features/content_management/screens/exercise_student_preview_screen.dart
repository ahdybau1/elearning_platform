import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/math_text.dart';

enum PreviewViewportMode {
  mobile,
  desktop,
}

/// Écran d'Aperçu Élève en immersion complète.
///
/// Permet à l'administrateur de tester fidèlement l'expérience élève
/// sur un format smartphone 390px centré ou en plein écran bureau.
class ExerciseStudentPreviewScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseStudentPreviewScreen({
    super.key,
    required this.exercise,
  });

  @override
  State<ExerciseStudentPreviewScreen> createState() =>
      _ExerciseStudentPreviewScreenState();
}

class _ExerciseStudentPreviewScreenState
    extends State<ExerciseStudentPreviewScreen> {
  PreviewViewportMode _viewportMode = PreviewViewportMode.mobile;

  int? _selectedOptionIndex;
  bool _isSubmitted = false;
  int _revealedHintsCount = 0;

  void _reset() {
    setState(() {
      _selectedOptionIndex = null;
      _isSubmitted = false;
      _revealedHintsCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final instructions = ex.instructionsJson;
    final solution = ex.solutionJson;
    final statement = instructions['statement'] as String? ?? ex.title;
    final options = (instructions['options'] as List?)
            ?.map((o) => o.toString())
            .toList() ??
        [];
    final media = (instructions['media'] as List?) ?? [];
    final solutionText = solution['correction'] as String? ??
        solution['explanation'] as String? ??
        '';
    final correctIndex = solution['correct_index'] as int?;
    final hints = ex.hints;

    final isCorrect = _selectedOptionIndex != null &&
        correctIndex != null &&
        _selectedOptionIndex == correctIndex;

    final contentWidget = _buildStudentContent(
      ex: ex,
      statement: statement,
      options: options,
      media: media,
      solutionText: solutionText,
      correctIndex: correctIndex,
      hints: hints,
      isCorrect: isCorrect,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate background
      appBar: AppBar(
        backgroundColor: AppTheme.primarySurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Fermer l\'aperçu',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aperçu Élève (Immersion Réelle)',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              ex.title,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Viewport toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewportBtn(
                  mode: PreviewViewportMode.mobile,
                  icon: Icons.smartphone_rounded,
                  label: 'Mobile (390px)',
                ),
                const SizedBox(width: 4),
                _buildViewportBtn(
                  mode: PreviewViewportMode.desktop,
                  icon: Icons.laptop_chromebook_rounded,
                  label: 'Plein Écran',
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentCyan),
            tooltip: 'Recommencer le test',
            onPressed: _reset,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: _viewportMode == PreviewViewportMode.mobile
            ? _buildMobileFrame(contentWidget)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: contentWidget,
                ),
              ),
      ),
    );
  }

  Widget _buildViewportBtn({
    required PreviewViewportMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _viewportMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _viewportMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFrame(Widget content) {
    return Container(
      width: 390,
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFF334155), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Simulateur barre d'état smartphone
          Container(
            height: 36,
            color: AppTheme.primarySurface,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '09:41',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                Container(
                  width: 80,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Icon(Icons.battery_full_rounded, size: 14, color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          // Contenu mobile scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: content,
            ),
          ),
          // Barre indicateur de retour accueil smartphone
          Container(
            height: 20,
            color: AppTheme.primarySurface,
            child: Center(
              child: Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentContent({
    required Exercise ex,
    required String statement,
    required List<String> options,
    required List media,
    required String solutionText,
    required int? correctIndex,
    required List<String> hints,
    required bool isCorrect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Badge élève
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                exerciseFormatToDb(ex.format).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                exerciseDifficultyToDb(ex.difficulty).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentAmber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Énoncé élève
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              MathText(
                statement,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),

        if (media.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: media.map((m) {
              final url = m is Map ? m['url']?.toString() : m.toString();
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url ?? '',
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 18),

        // Options QCM si présentes
        if (options.isNotEmpty) ...[
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildStudentOption(
              letter: String.fromCharCode(65 + i),
              text: options[i],
              index: i,
              isCorrectTarget: correctIndex == i,
            ),
          ],
          const SizedBox(height: 20),

          // Bouton de validation
          if (!_isSubmitted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedOptionIndex != null
                    ? AppTheme.accentCyan
                    : Colors.white12,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _selectedOptionIndex != null
                  ? () => setState(() => _isSubmitted = true)
                  : null,
              child: Text(
                'Valider ma réponse',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _selectedOptionIndex != null ? Colors.black : Colors.white38,
                ),
              ),
            )
          else
            _buildFeedbackBanner(isCorrect, solutionText),
        ],

        // Tiroir d'indices
        if (hints.isNotEmpty && !_isSubmitted) ...[
          const SizedBox(height: 16),
          if (_revealedHintsCount < hints.length)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentAmber,
                side: const BorderSide(color: AppTheme.accentAmber),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => setState(() => _revealedHintsCount++),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
              label: Text(
                'Besoin d\'un indice ? ($_revealedHintsCount/${hints.length})',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          for (int h = 0; h < _revealedHintsCount; h++) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: AppTheme.accentAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hints[h],
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStudentOption({
    required String letter,
    required String text,
    required int index,
    required bool isCorrectTarget,
  }) {
    final isSelected = _selectedOptionIndex == index;
    Color borderColor = AppTheme.primaryBorder;
    Color bgColor = AppTheme.primarySurface;

    if (_isSubmitted) {
      if (isCorrectTarget) {
        borderColor = AppTheme.accentEmerald;
        bgColor = AppTheme.accentEmerald.withValues(alpha: 0.15);
      } else if (isSelected) {
        borderColor = AppTheme.accentRose;
        bgColor = AppTheme.accentRose.withValues(alpha: 0.15);
      }
    } else if (isSelected) {
      borderColor = AppTheme.accentCyan;
      bgColor = AppTheme.accentCyan.withValues(alpha: 0.12);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isSubmitted
          ? null
          : () => setState(() => _selectedOptionIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppTheme.accentCyan
                    : AppTheme.primaryDark,
                border: Border.all(
                  color: isSelected ? AppTheme.accentCyan : AppTheme.primaryBorder,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MathText(
                text,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner(bool isCorrect, String solutionText) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppTheme.accentEmerald.withValues(alpha: 0.15)
            : AppTheme.accentRose.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? AppTheme.accentEmerald : AppTheme.accentRose,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isCorrect ? AppTheme.accentEmerald : AppTheme.accentRose,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? 'Excellent ! Bonne réponse.' : 'Pas tout à fait...',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? AppTheme.accentEmerald : AppTheme.accentRose,
                ),
              ),
            ],
          ),
          if (solutionText.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.primaryBorder),
            const SizedBox(height: 8),
            Text(
              'Explication didactique :',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            MathText(
              solutionText,
              style: GoogleFonts.inter(fontSize: 13, height: 1.6, color: Colors.white),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _reset,
            child: const Text('Recommencer'),
          ),
        ],
      ),
    );
  }
}
