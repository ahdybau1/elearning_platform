import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/curriculum_preview_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/design_system/tokens/elef_colors.dart';
import '../../../core/design_system/tokens/elef_typography.dart';
import '../../../core/design_system/tokens/elef_radius.dart';
import 'academic_tree_screen.dart';

/// Écran Curriculum Autopilot
/// Intègre l'Agent de Rattachement Curriculaire (AIA-AGT-017) avec revue humaine obligatoire (HITL).
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
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _analysisError = 'Veuillez saisir ou coller un extrait de programme ou sommaire.';
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
      if (mounted) {
        setState(() {
          _mappingResult = res;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = e.toString().replaceFirst('Exception: ', '');
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primaryDark,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Curriculum Autopilot',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Collecte automatique non raccordée à cet écran.',
          style: TextStyle(
            color: AppTheme.accentAmber,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aucun programme n’a été collecté, certifié ou injecté. Les programmes doivent être reliés à leurs sources, puis relus avant publication.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Ouvrir l’arbre académique'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Arbre académique')),
                  body: const AcademicTreeScreen(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Panneau interactif de l'Agent IA Métier (AIA-AGT-017)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ElefColors.surfaceCard,
            borderRadius: ElefRadius.lg,
            border: Border.all(color: ElefColors.primary.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ElefColors.primary.withAlpha(40),
                      borderRadius: ElefRadius.sm,
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: ElefColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analyse et Rattachement Curriculaire (AIA-AGT-017)',
                          style: ElefTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Proposer les chapitres et compétences cibles à partir d\'un extrait de cours ou syllabus officiel.',
                          style: ElefTypography.caption.copyWith(
                            color: ElefColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _textController,
                style: ElefTypography.bodyMedium.copyWith(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Collez ici l\'extrait du programme ou les objectifs pédagogiques (ex: Suites numériques, raison de récurrence, convergence, limites)...',
                  hintStyle: ElefTypography.bodySmall.copyWith(color: ElefColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF090D18),
                  border: OutlineInputBorder(
                    borderRadius: ElefRadius.md,
                    borderSide: const BorderSide(color: ElefColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _runAnalysis,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(_isAnalyzing ? 'Analyse en cours...' : 'Analyser le contenu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ElefColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  if (_textController.text.isNotEmpty)
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ElefColors.danger.withAlpha(20),
                    borderRadius: ElefRadius.sm,
                    border: Border.all(color: ElefColors.danger.withAlpha(80)),
                  ),
                  child: Text(
                    _analysisError!,
                    style: ElefTypography.bodySmall.copyWith(color: ElefColors.danger),
                  ),
                ),
              ],

              // Affichage des candidats identifiés par l'agent IA
              if (_mappingResult != null) ...[
                const SizedBox(height: 16),
                const Divider(color: ElefColors.borderSubtle),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      _mappingResult!['needs_human_review'] == true
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _mappingResult!['needs_human_review'] == true
                          ? ElefColors.warning
                          : ElefColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mappingResult!['recommendation']?.toString() ?? 'Résultats de correspondance :',
                        style: ElefTypography.labelMedium.copyWith(
                          color: _mappingResult!['needs_human_review'] == true
                              ? ElefColors.warning
                              : ElefColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  'Chapitres cibles détectés :',
                  style: ElefTypography.titleSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                if ((_mappingResult!['chapter_candidates'] as List?)?.isEmpty ?? true)
                  Text('Aucun chapitre correspondant identifié.', style: ElefTypography.caption)
                else
                  ...((_mappingResult!['chapter_candidates'] as List).map((c) {
                    final item = Map<String, dynamic>.from(c as Map);
                    final conf = (item['confidence'] as num?)?.toDouble() ?? 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D18),
                        borderRadius: ElefRadius.md,
                        border: Border.all(color: ElefColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] ?? item['chapter_id'] ?? 'Chapitre',
                                  style: ElefTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item['evidence'] != null)
                                  Text(
                                    item['evidence'].toString(),
                                    style: ElefTypography.caption.copyWith(color: ElefColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: conf >= 0.7
                                  ? ElefColors.success.withAlpha(30)
                                  : ElefColors.warning.withAlpha(30),
                              borderRadius: ElefRadius.xs,
                            ),
                            child: Text(
                              '${(conf * 100).toInt()}% conf.',
                              style: ElefTypography.caption.copyWith(
                                color: conf >= 0.7 ? ElefColors.success : ElefColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })),

                const SizedBox(height: 10),
                Text(
                  'Compétences associées :',
                  style: ElefTypography.titleSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                if ((_mappingResult!['skill_candidates'] as List?)?.isEmpty ?? true)
                  Text('Aucune compétence spécifique trouvée.', style: ElefTypography.caption)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: (_mappingResult!['skill_candidates'] as List).map((s) {
                      final item = Map<String, dynamic>.from(s as Map);
                      return Chip(
                        backgroundColor: const Color(0xFF090D18),
                        side: const BorderSide(color: ElefColors.primary),
                        label: Text(
                          item['name']?.toString() ?? 'Compétence',
                          style: ElefTypography.caption.copyWith(color: Colors.white),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'EXEMPLE DE STRUCTURE — NON VALIDÉ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cet exemple local du Cameroun illustre l’organisation attendue. Il ne constitue pas un référentiel officiel et n’est pas enregistré dans la base.',
        ),
        const SizedBox(height: 12),
        for (final node in sampleCurriculum()) _node(node),
      ],
    ),
  );

  Widget _node(CurriculumCandidateNode node) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
    childrenPadding: const EdgeInsets.only(left: 8),
    title: Text(node.title),
    children: [
      if (node.coefficient != null)
        Text('Coefficient d’exemple : ${node.coefficient}'),
      if (node.trimester != null)
        Text('Trimestre d’exemple : ${node.trimester}'),
      for (final skill in node.skills)
        ListTile(dense: true, title: Text(skill)),
      for (final child in node.children) _node(child),
    ],
  );
}

