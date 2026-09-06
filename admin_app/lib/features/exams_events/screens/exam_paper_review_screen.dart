import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/math_text.dart';

/// Aperçu du rendu réel d'une formule LaTeX pendant la relecture — l'admin doit pouvoir vérifier
/// que la transcription OCR donne bien la formule attendue, pas juste une chaîne `$...$` brute.
/// N'apparaît que si le texte contient réellement du LaTeX (sinon l'aperçu dupliquerait le champ).
class _MathPreview extends StatelessWidget {
  const _MathPreview(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    if (!MathText.containsMath(text)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aperçu', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            MathText(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// D.8–D.9 : la décision humaine porte sur le texte effectivement enregistré.
class ExamPaperReviewScreen extends ConsumerStatefulWidget {
  const ExamPaperReviewScreen({super.key, this.examPaperId,
    this.establishmentPaperId, required this.paperLabel})
      : assert((examPaperId == null) != (establishmentPaperId == null));
  final String? examPaperId;
  final String? establishmentPaperId;
  final String paperLabel;
  @override
  ConsumerState<ExamPaperReviewScreen> createState() => _ExamPaperReviewScreenState();
}

class _ExamPaperReviewScreenState extends ConsumerState<ExamPaperReviewScreen> {
  final _saved = <String, ExamPaperQuestion>{};
  final _dirty = <String>{};
  final _saving = <String>{};
  bool _publishing = false;
  ({String? examPaperId, String? establishmentPaperId}) get _ids =>
    (examPaperId: widget.examPaperId, establishmentPaperId: widget.establishmentPaperId);

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await ref.read(supabaseServiceProvider).publishExamPaper(
        examPaperId: widget.examPaperId, establishmentPaperId: widget.establishmentPaperId);
      if (!mounted) return;
      ref.invalidate(examPapersProvider);
      ref.invalidate(establishmentPapersProvider);
      // PopScope must be rebuilt before leaving the screen.
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet publié.')));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publication impossible : $error')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(examPaperQuestionsProvider(_ids));
    return PopScope(
      canPop: _dirty.isEmpty && _saving.isEmpty && !_publishing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrez ou annulez vos modifications avant de quitter.')));
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryDark,
        appBar: AppBar(title: Text('Révision — ${widget.paperLabel}')),
        body: questionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Chargement impossible : $error')),
          data: (initial) {
            final questions = initial.map((q) => _saved[q.id] ?? q).toList();
            if (questions.isEmpty) return const Center(child: Text('Aucune question extraite pour ce sujet.'));
            final approved = questions.where((q) => q.status == 'approved').length;
            return Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: Wrap(
                spacing: 20, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('$approved / ${questions.length} question(s) approuvée(s)'),
                  FilledButton.icon(
                    onPressed: approved == questions.length && _dirty.isEmpty &&
                      _saving.isEmpty && !_publishing ? _publish : null,
                    icon: const Icon(Icons.publish_rounded),
                    label: Text(_publishing ? 'Publication…' : 'Publier')),
                  if (_dirty.isNotEmpty) const Text('Modifications non enregistrées'),
                ])),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(
                'Relisez les énoncés et les corrigés proposés par l’IA. '
                'Toute modification d’un sujet publié impose une nouvelle publication.')),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final q = questions[index];
                  return ExamQuestionReviewCard(
                    key: ValueKey(q.id), question: q, disabled: _publishing,
                    onDirtyChanged: (dirty) => setState(() {
                      if (dirty) { _dirty.add(q.id); } else { _dirty.remove(q.id); }
                    }),
                    onSave: (statement, answer, status, notes) async {
                      setState(() => _saving.add(q.id));
                      try {
                        final saved = await ref.read(supabaseServiceProvider).updateExamPaperQuestion(
                          id: q.id, expectedRevision: q.revision, statement: statement,
                          proposedAnswer: answer, status: status, reviewerNotes: notes);
                        if (mounted) setState(() => _saved[q.id] = saved);
                      } finally {
                        if (mounted) setState(() => _saving.remove(q.id));
                      }
                    },
                  );
                },
              )),
            ]);
          },
        ),
      ),
    );
  }
}

class ExamQuestionReviewCard extends StatefulWidget {
  const ExamQuestionReviewCard({super.key, required this.question,
    required this.onSave, required this.onDirtyChanged, this.disabled = false});
  final ExamPaperQuestion question;
  final bool disabled;
  final Future<void> Function(String statement, String answer, String status, String notes) onSave;
  final ValueChanged<bool> onDirtyChanged;
  @override
  State<ExamQuestionReviewCard> createState() => _ExamQuestionReviewCardState();
}

class _ExamQuestionReviewCardState extends State<ExamQuestionReviewCard>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _statement;
  late final TextEditingController _answer;
  late final TextEditingController _notes;
  bool _dirty = false;
  bool _busy = false;
  String? _error;
  @override
  bool get wantKeepAlive => _dirty || _busy;
  @override
  void initState() {
    super.initState();
    _statement = TextEditingController(text: widget.question.statement);
    _answer = TextEditingController(text: widget.question.proposedAnswer ?? '');
    _notes = TextEditingController(text: widget.question.reviewerNotes ?? '');
  }
  @override
  void didUpdateWidget(covariant ExamQuestionReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && !_busy && oldWidget.question.revision != widget.question.revision) _restore();
  }
  void _restore() {
    _statement.text = widget.question.statement;
    _answer.text = widget.question.proposedAnswer ?? '';
    _notes.text = widget.question.reviewerNotes ?? '';
  }
  void _changed(String _) {
    setState(() => _dirty = true);
    updateKeepAlive();
    widget.onDirtyChanged(true);
  }
  Future<void> _save(String status) async {
    if (_statement.text.trim().isEmpty) {
      setState(() => _error = 'L’énoncé ne peut pas être vide.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    updateKeepAlive();
    try {
      await widget.onSave(_statement.text.trim(), _answer.text.trim(), status, _notes.text.trim());
      if (!mounted) return;
      setState(() => _dirty = false);
      widget.onDirtyChanged(false);
    } catch (error) {
      if (mounted) setState(() => _error = 'Enregistrement impossible : $error');
    } finally {
      if (mounted) { setState(() => _busy = false); updateKeepAlive(); }
    }
  }
  @override
  void dispose() {
    _statement.dispose(); _answer.dispose(); _notes.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final q = widget.question;
    final disabled = _busy || widget.disabled;
    final label = switch (q.status) {
      'approved' => 'Approuvée', 'needs_changes' => 'À corriger', _ => 'En attente de relecture',
    };
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Question ${q.questionOrder}', style: Theme.of(context).textTheme.titleMedium),
          Chip(label: Text(label)),
          if (q.confidence != null) Text('Confiance IA : ${(q.confidence! * 100).round()} %'),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _statement, enabled: !disabled, maxLines: null,
          decoration: const InputDecoration(labelText: 'Énoncé'), onChanged: _changed),
        _MathPreview(_statement.text),
        const SizedBox(height: 12),
        TextField(controller: _answer, enabled: !disabled, maxLines: null,
          decoration: const InputDecoration(labelText: 'Corrigé proposé'), onChanged: _changed),
        _MathPreview(_answer.text),
        const SizedBox(height: 12),
        TextField(controller: _notes, enabled: !disabled, maxLines: null,
          decoration: const InputDecoration(labelText: 'Note de relecture (optionnel)'), onChanged: _changed),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_dirty) OutlinedButton(onPressed: disabled ? null : () => _save('waiting_review'),
            child: const Text('Enregistrer')),
          FilledButton.icon(onPressed: disabled ? null : () => _save('approved'),
            icon: const Icon(Icons.check_circle_outline), label: Text(_busy ? 'Enregistrement…' : 'Approuver')),
          OutlinedButton(onPressed: disabled ? null : () => _save('needs_changes'),
            child: const Text('À corriger')),
          if (_dirty) TextButton(onPressed: disabled ? null : () {
            setState(() { _restore(); _dirty = false; _error = null; });
            updateKeepAlive(); widget.onDirtyChanged(false);
          }, child: const Text('Annuler les modifications')),
        ]),
      ],
    )));
  }
}
