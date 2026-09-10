import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/curriculum_preview_data.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import '../../../core/design_system/tokens/elef_spacing.dart';

/// Curriculum Autopilot (D.3) — assistant de **rattachement curriculaire**.
///
/// Intègre l'agent AIA-AGT-017 (`ai-curriculum-mapping`, Edge Function déterministe, sans appel
/// modèle payant) : à partir d'un extrait de programme ou d'un sommaire, il propose les chapitres
/// et compétences **déjà présents en base** qui correspondent. Aucune écriture automatique : toute
/// création ou tout rattachement se fait ensuite à la main dans « Leçons & Cours » ou l'arbre
/// académique, après revue humaine (HITL). L'exemple de structure en bas de page est une
/// illustration non normative, jamais enregistrée.
class CurriculumAutopilotScreen extends ConsumerStatefulWidget {
  const CurriculumAutopilotScreen({super.key});

  @override
  ConsumerState<CurriculumAutopilotScreen> createState() =>
      _CurriculumAutopilotScreenState();
}

class _CurriculumAutopilotScreenState
    extends ConsumerState<CurriculumAutopilotScreen> {
  final _textController = TextEditingController();
  bool _isAnalyzing = false;
  String? _analysisError;
  Map<String, dynamic>? _mappingResult;

  @override
  void initState() {
    super.initState();
    // Rendre l'UI réactive à la saisie (bouton « Analyser » activé/désactivé, bouton « Effacer »).
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _analysisError =
            'Veuillez saisir ou coller un extrait de programme ou un sommaire.';
        _mappingResult = null;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      final service = ref.read(supabaseServiceProvider);
      final res = await service.mapCurriculumWithAi(text);
      if (!mounted) return;
      setState(() {
        _mappingResult = res;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysisError = e.toString().replaceFirst('Exception: ', '');
        _isAnalyzing = false;
      });
    }
  }

  void _goToLessonsManager() {
    ref.read(selectedNavIndexProvider.notifier).state = 2; // Leçons & Cours
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElefColors.background,
      body: ListView(
        padding: ElefSpacing.paddingLg,
        children: [
          Text('Curriculum Autopilot', style: ElefTypography.displayMedium),
          const SizedBox(height: ElefSpacing.xs),
          Text(
            "Assistant de rattachement curriculaire (AIA-AGT-017). Analyse déterministe par "
            "mots-clés, sans coût d'API. Aucune écriture automatique : les rattachements se font "
            "à la main après revue.",
            style: ElefTypography.bodyMedium,
          ),
          const SizedBox(height: ElefSpacing.lg),
          _buildAnalyzerCard(),
          const SizedBox(height: ElefSpacing.lg),
          _buildSampleSection(),
        ],
      ),
    );
  }

  Widget _buildAnalyzerCard() {
    final canAnalyze = _textController.text.trim().isNotEmpty && !_isAnalyzing;
    return Container(
      padding: ElefSpacing.paddingMd,
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: ElefSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: ElefColors.primary.withValues(alpha: 0.15),
                  borderRadius: ElefRadius.sm,
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: ElefColors.primary, size: 20),
              ),
              const SizedBox(width: ElefSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analyse et rattachement curriculaire',
                        style: ElefTypography.titleMedium),
                    Text(
                      "Proposer les chapitres et compétences cibles à partir d'un extrait de "
                      "cours ou d'un syllabus officiel.",
                      style: ElefTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ElefSpacing.md),
          TextField(
            controller: _textController,
            style: ElefTypography.bodyMedium.copyWith(color: ElefColors.textPrimary),
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  "Collez ici l'extrait du programme ou les objectifs pédagogiques "
                  "(ex : suites numériques, raison de récurrence, convergence, limites)…",
              hintStyle: ElefTypography.bodySmall,
              filled: true,
              fillColor: ElefColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: ElefRadius.md,
                borderSide: const BorderSide(color: ElefColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ElefRadius.md,
                borderSide: const BorderSide(color: ElefColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ElefRadius.md,
                borderSide: const BorderSide(color: ElefColors.borderActive),
              ),
            ),
          ),
          const SizedBox(height: ElefSpacing.sm),
          Wrap(
            spacing: ElefSpacing.md,
            runSpacing: ElefSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: canAnalyze ? _runAnalysis : null,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: Text(_isAnalyzing ? 'Analyse en cours…' : 'Analyser le contenu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ElefColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ElefColors.surfaceElevated,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (_textController.text.isNotEmpty && !_isAnalyzing)
                TextButton(
                  onPressed: () {
                    _textController.clear();
                    setState(() {
                      _mappingResult = null;
                      _analysisError = null;
                    });
                  },
                  child: const Text('Effacer'),
                ),
            ],
          ),
          if (_analysisError != null) ...[
            const SizedBox(height: ElefSpacing.md),
            Container(
              padding: ElefSpacing.paddingSm,
              decoration: BoxDecoration(
                color: ElefColors.dangerBg,
                borderRadius: ElefRadius.sm,
                border: Border.all(color: ElefColors.dangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: ElefColors.danger, size: 16),
                  const SizedBox(width: ElefSpacing.sm),
                  Expanded(
                    child: Text(_analysisError!,
                        style: ElefTypography.bodySmall
                            .copyWith(color: ElefColors.danger)),
                  ),
                ],
              ),
            ),
          ],
          if (_mappingResult != null) ...[
            const SizedBox(height: ElefSpacing.md),
            const Divider(color: ElefColors.borderSubtle),
            const SizedBox(height: ElefSpacing.sm),
            _buildResult(_mappingResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    final needsReview = result['needs_human_review'] == true;
    final chapterCandidates =
        (result['chapter_candidates'] as List?)?.cast<dynamic>() ?? const [];
    final skillCandidates =
        (result['skill_candidates'] as List?)?.cast<dynamic>() ?? const [];
    final keywordCount = result['input_keywords_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: ElefSpacing.paddingSm,
          decoration: BoxDecoration(
            color: needsReview ? ElefColors.warningBg : ElefColors.successBg,
            borderRadius: ElefRadius.sm,
            border: Border.all(
                color: needsReview
                    ? ElefColors.warningBorder
                    : ElefColors.successBorder),
          ),
          child: Row(
            children: [
              Icon(
                needsReview
                    ? Icons.rate_review_rounded
                    : Icons.check_circle_outline_rounded,
                color: needsReview ? ElefColors.warning : ElefColors.success,
                size: 18,
              ),
              const SizedBox(width: ElefSpacing.sm),
              Expanded(
                child: Text(
                  (result['recommendation'] ?? 'Analyse terminée.').toString(),
                  style: ElefTypography.labelMedium.copyWith(
                    color: needsReview ? ElefColors.warning : ElefColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ElefSpacing.xs),
        Text('$keywordCount mots-clés significatifs extraits · méthode déterministe.',
            style: ElefTypography.caption),
        const SizedBox(height: ElefSpacing.md),
        Text('Chapitres existants correspondants', style: ElefTypography.titleSmall),
        const SizedBox(height: ElefSpacing.xs),
        if (chapterCandidates.isEmpty)
          Text(
            'Aucun chapitre existant ne correspond. Créez-le manuellement dans « Leçons & Cours ».',
            style: ElefTypography.bodySmall,
          )
        else
          ...chapterCandidates.map((c) =>
              _chapterCandidateRow(Map<String, dynamic>.from(c as Map))),
        const SizedBox(height: ElefSpacing.md),
        Text('Compétences existantes associées', style: ElefTypography.titleSmall),
        const SizedBox(height: ElefSpacing.xs),
        if (skillCandidates.isEmpty)
          Text('Aucune compétence enregistrée ne correspond.',
              style: ElefTypography.bodySmall)
        else
          Wrap(
            spacing: ElefSpacing.sm,
            runSpacing: ElefSpacing.xs,
            children: skillCandidates.map((s) {
              final item = Map<String, dynamic>.from(s as Map);
              final conf = ((item['confidence'] as num?)?.toDouble() ?? 0) * 100;
              return Chip(
                backgroundColor: ElefColors.surfaceDark,
                side: const BorderSide(color: ElefColors.borderMedium),
                label: Text(
                  '${item['name'] ?? 'Compétence'} · ${conf.toInt()}%',
                  style: ElefTypography.caption
                      .copyWith(color: ElefColors.textSecondary),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _chapterCandidateRow(Map<String, dynamic> item) {
    final conf = (item['confidence'] as num?)?.toDouble() ?? 0.0;
    final strong = conf >= 0.5;
    return Container(
      margin: const EdgeInsets.only(bottom: ElefSpacing.sm),
      padding: ElefSpacing.paddingSm,
      decoration: BoxDecoration(
        color: ElefColors.surfaceDark,
        borderRadius: ElefRadius.md,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (item['title'] ?? item['chapter_id'] ?? 'Chapitre').toString(),
                  style: ElefTypography.titleSmall,
                ),
              ),
              const SizedBox(width: ElefSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (strong ? ElefColors.success : ElefColors.warning)
                      .withValues(alpha: 0.15),
                  borderRadius: ElefRadius.xs,
                ),
                child: Text(
                  '${(conf * 100).toInt()}% conf.',
                  style: ElefTypography.badge.copyWith(
                      color: strong ? ElefColors.success : ElefColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElefSpacing.xxs),
          Text(
            [
              if ((item['subject_name'] ?? '').toString().isNotEmpty)
                item['subject_name'],
              if ((item['level_name'] ?? '').toString().isNotEmpty)
                item['level_name'],
            ].join(' · '),
            style: ElefTypography.caption,
          ),
          if ((item['evidence'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: ElefSpacing.xxs),
            Text(item['evidence'].toString(),
                style: ElefTypography.bodySmall),
          ],
          const SizedBox(height: ElefSpacing.sm),
          Wrap(
            spacing: ElefSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _goToLessonsManager,
                icon: const Icon(Icons.menu_book_rounded, size: 15),
                label: const Text('Gérer dans Leçons & Cours'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ElefColors.primary,
                  side: const BorderSide(color: ElefColors.borderMedium),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: (item['chapter_id'] ?? '').toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Identifiant du chapitre copié.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copier l’ID'),
                style: TextButton.styleFrom(
                    foregroundColor: ElefColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSampleSection() {
    return Container(
      padding: ElefSpacing.paddingMd,
      decoration: BoxDecoration(
        color: ElefColors.surfaceCard,
        borderRadius: ElefRadius.lg,
        border: Border.all(color: ElefColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: ElefColors.textMuted),
              const SizedBox(width: ElefSpacing.sm),
              Expanded(
                child: Text('Exemple de structure — non normatif',
                    style: ElefTypography.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: ElefSpacing.xs),
          Text(
            "Cet exemple local (Cameroun) illustre l'organisation attendue. Il ne constitue pas "
            "un référentiel officiel et n'est pas enregistré en base.",
            style: ElefTypography.bodySmall,
          ),
          const SizedBox(height: ElefSpacing.sm),
          // Material transparent : les ExpansionTile/ListTile internes ont besoin d'un ancêtre
          // Material sans DecoratedBox coloré intermédiaire (sinon l'assertion Flutter
          // « ListTile background may be invisible »).
          Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final node in sampleCurriculum()) _sampleNode(node),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sampleNode(CurriculumCandidateNode node) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(node.title, style: ElefTypography.bodyMedium),
          iconColor: ElefColors.textMuted,
          collapsedIconColor: ElefColors.textMuted,
          children: [
            if (node.coefficient != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('Coefficient d’exemple : ${node.coefficient}',
                    style: ElefTypography.caption),
              ),
            if (node.trimester != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('Trimestre d’exemple : ${node.trimester}',
                    style: ElefTypography.caption),
              ),
            for (final skill in node.skills)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: ElefColors.textMuted)),
                    Expanded(
                        child: Text(skill, style: ElefTypography.bodySmall)),
                  ],
                ),
              ),
            for (final child in node.children) _sampleNode(child),
          ],
        ),
      );
}
