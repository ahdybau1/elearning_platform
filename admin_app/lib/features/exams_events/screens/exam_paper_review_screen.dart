import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// Écran de révision Exam Resource Factory (Tranche 1 — docs/CAHIER_IA_ZERO_COUT_MASTER.md
/// Annexe D.8-D.9) : l'admin relit, corrige et approuve chaque question extraite par l'IA avant
/// de publier. Rien n'est visible côté élève tant que `processing_status` du sujet parent n'est
/// pas passé à `published` (et cette tranche n'ajoute aucune lecture élève de toute façon).
class ExamPaperReviewScreen extends ConsumerStatefulWidget {
  const ExamPaperReviewScreen({
    super.key,
    this.examPaperId,
    this.establishmentPaperId,
    required this.paperLabel,
  }) : assert((examPaperId == null) != (establishmentPaperId == null));

  final String? examPaperId;
  final String? establishmentPaperId;
  final String paperLabel;

  @override
  ConsumerState<ExamPaperReviewScreen> createState() => _ExamPaperReviewScreenState();
}

class _ExamPaperReviewScreenState extends ConsumerState<ExamPaperReviewScreen> {
  bool _publishing = false;

  ({String? examPaperId, String? establishmentPaperId}) get _ids =>
      (examPaperId: widget.examPaperId, establishmentPaperId: widget.establishmentPaperId);

  Future<void> _saveQuestion(
    ExamPaperQuestion q, {
    String? statement,
    String? proposedAnswer,
    String? status,
    String? reviewerNotes,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateExamPaperQuestion(
        id: q.id,
        statement: statement,
        proposedAnswer: proposedAnswer,
        status: status,
        reviewerNotes: reviewerNotes,
      );
      ref.invalidate(examPaperQuestionsProvider(_ids));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Échec de l\'enregistrement : $e')),
      );
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.publishExamPaper(
        examPaperId: widget.examPaperId,
        establishmentPaperId: widget.establishmentPaperId,
      );
      messenger.showSnackBar(
        const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Sujet publié.')),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRose, content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(examPaperQuestionsProvider(_ids));

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primarySurface,
        title: Text('Révision IA — ${widget.paperLabel}',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Text('Aucune question extraite pour ce sujet.',
                  style: GoogleFonts.inter(color: AppTheme.textMuted)),
            );
          }
          final approvedCount = questions.where((q) => q.status == 'approved').length;
          final allApproved = approvedCount == questions.length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.primarySurface,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$approvedCount / ${questions.length} question(s) approuvée(s)',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (allApproved && !_publishing) ? _publish : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        disabledBackgroundColor: AppTheme.primaryBorder,
                      ),
                      icon: _publishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.publish_rounded, size: 18),
                      label: const Text('Publier'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  itemBuilder: (context, i) => _QuestionCard(
                    question: questions[i],
                    onSave: (statement, proposedAnswer, status, reviewerNotes) => _saveQuestion(
                      questions[i],
                      statement: statement,
                      proposedAnswer: proposedAnswer,
                      status: status,
                      reviewerNotes: reviewerNotes,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Erreur : $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({required this.question, required this.onSave});

  final ExamPaperQuestion question;
  final void Function(String? statement, String? proposedAnswer, String? status, String? reviewerNotes)
      onSave;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _statementController;
  late final TextEditingController _answerController;
  late final TextEditingController _notesController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _statementController = TextEditingController(text: widget.question.statement);
    _answerController = TextEditingController(text: widget.question.proposedAnswer ?? '');
    _notesController = TextEditingController(text: widget.question.reviewerNotes ?? '');
  }

  @override
  void dispose() {
    _statementController.dispose();
    _answerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.accentEmerald;
      case 'needs_changes':
        return AppTheme.accentRose;
      default:
        return AppTheme.accentAmber;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approuvée';
      case 'needs_changes':
        return 'À corriger';
      default:
        return 'En attente de relecture';
    }
  }

  void _saveEdits() {
    widget.onSave(_statementController.text, _answerController.text, null, null);
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Question ${q.questionOrder}',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(q.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(q.status),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(q.status))),
              ),
              if (q.confidence != null) ...[
                const SizedBox(width: 8),
                Text('confiance IA : ${(q.confidence! * 100).round()}%',
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _statementController,
            maxLines: null,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            decoration: const InputDecoration(labelText: 'Énoncé', isDense: true),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            maxLines: null,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            decoration: const InputDecoration(labelText: 'Corrigé proposé', isDense: true),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
            decoration: const InputDecoration(labelText: 'Note de relecture (optionnel)', isDense: true),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_dirty)
                ElevatedButton.icon(
                  onPressed: _saveEdits,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Enregistrer'),
                ),
              OutlinedButton.icon(
                onPressed: () => widget.onSave(null, null, 'approved', _notesController.text),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentEmerald),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Approuver'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onSave(null, null, 'needs_changes', _notesController.text),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRose),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('À corriger'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
