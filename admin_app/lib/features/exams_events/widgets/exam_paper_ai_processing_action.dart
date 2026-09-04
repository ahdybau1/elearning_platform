import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/exam_paper_review_screen.dart';

/// Action IA compacte affichée sur chaque ligne de sujet (Exam Resource Factory, Tranche 1 —
/// docs/CAHIER_IA_ZERO_COUT_MASTER.md Annexe D.8-D.9). Réutilisée à l'identique par
/// official_exams_screen.dart et school_papers_screen.dart pour éviter la duplication. Exactement
/// un des deux identifiants (sujet national OU d'établissement) est fourni.
class ExamPaperAiProcessingAction extends ConsumerStatefulWidget {
  const ExamPaperAiProcessingAction({
    super.key,
    this.examPaperId,
    this.establishmentPaperId,
    required this.processingStatus,
    required this.paperLabel,
    required this.onChanged,
  }) : assert((examPaperId == null) != (establishmentPaperId == null));

  final String? examPaperId;
  final String? establishmentPaperId;
  final String processingStatus;
  final String paperLabel;
  final VoidCallback onChanged;

  @override
  ConsumerState<ExamPaperAiProcessingAction> createState() =>
      _ExamPaperAiProcessingActionState();
}

class _ExamPaperAiProcessingActionState
    extends ConsumerState<ExamPaperAiProcessingAction> {
  bool _busy = false;

  Future<void> _process() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(supabaseServiceProvider);
      final count = await service.processExamPaperWithAi(
        examPaperId: widget.examPaperId,
        establishmentPaperId: widget.establishmentPaperId,
      );
      widget.onChanged();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text('$count question(s) extraite(s) — à relire.'),
        ),
      );
    } catch (e) {
      widget.onChanged();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentRose,
          content: Text('Échec IA : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openReview() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ExamPaperReviewScreen(
              examPaperId: widget.examPaperId,
              establishmentPaperId: widget.establishmentPaperId,
              paperLabel: widget.paperLabel,
            ),
          ),
        )
        .then((_) => widget.onChanged());
  }

  @override
  Widget build(BuildContext context) {
    if (_busy || widget.processingStatus == 'processing') {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.accentCyan),
        ),
      );
    }
    switch (widget.processingStatus) {
      case 'waiting_review':
        return IconButton(
          icon: const Icon(Icons.rate_review_rounded,
              color: AppTheme.accentAmber, size: 18),
          tooltip: 'Réviser les questions extraites par l\'IA',
          onPressed: _openReview,
        );
      case 'published':
        return IconButton(
          icon: const Icon(Icons.auto_awesome_rounded,
              color: AppTheme.accentEmerald, size: 18),
          tooltip: 'Questions publiées — voir/éditer',
          onPressed: _openReview,
        );
      case 'failed':
        return IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppTheme.accentRose, size: 18),
          tooltip: 'Échec du traitement IA — relancer',
          onPressed: _process,
        );
      case 'not_started':
      default:
        return IconButton(
          icon: const Icon(Icons.auto_awesome_rounded,
              color: AppTheme.accentCyan, size: 18),
          tooltip: 'Traiter avec l\'IA (OCR + découpage en questions)',
          onPressed: _process,
        );
    }
  }
}
