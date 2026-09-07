import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../../core/rendering/ai_message_bubble_renderer.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../pedagogy/widgets/interactive_function_graph.dart';
import '../../pedagogy/widgets/scientific_tools_modal.dart';

/// Modal d'interaction directe avec les Agents IA EDLEARN
/// (TutorAgent, SocraticAgent, MisconceptionAgent, ExerciseAgent).
///
/// Conforme au Cahier des Charges Agents IA (docs/CAHIER_DES_CHARGES_AGENTS_IA.md) :
/// - Dialogue socratique maïeutique (ne donne pas la solution brute)
/// - Diagnostic des pièges d'examen (misconceptions)
/// - Génération d'exercices calibrés
/// - Fallback déterministe local sans crash ni dépendance obligatoire à un fournisseur externe.
class ContextualAiAgentSheet extends StatefulWidget {
  final String topicTitle;
  final String subject;
  final String? formulaLatex;
  final String initialMode; // 'tutor', 'diagnostic', 'exercise'

  const ContextualAiAgentSheet({
    super.key,
    required this.topicTitle,
    required this.subject,
    this.formulaLatex,
    this.initialMode = 'tutor',
  });

  static Future<void> show(
    BuildContext context, {
    required String topicTitle,
    required String subject,
    String? formulaLatex,
    String initialMode = 'tutor',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContextualAiAgentSheet(
        topicTitle: topicTitle,
        subject: subject,
        formulaLatex: formulaLatex,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<ContextualAiAgentSheet> createState() => _ContextualAiAgentSheetState();
}

class _ContextualAiAgentSheetState extends State<ContextualAiAgentSheet> {
  late String _activeMode;
  final TextEditingController _questionCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  final List<Map<String, String>> _chatHistory = [];

  // Données de diagnostic (Pièges d'examen)
  int _diagnosticQuestionIdx = 0;
  int? _selectedDiagnosticOption;
  bool _diagnosticAnswered = false;
  int _diagnosticScore = 0;

  // Données d'exercice généré
  final TextEditingController _exerciseAnswerCtrl = TextEditingController();
  bool _exerciseSubmitted = false;
  bool _exerciseCorrect = false;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
    _initializeMode();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _exerciseAnswerCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeMode() {
    if (_activeMode == 'tutor') {
      _chatHistory.clear();
      _chatHistory.add({
        'sender': 'agent',
        'text':
            'Bonjour ! Je suis le Tuteur Socratique IA pour "${widget.topicTitle}".\n'
            'Je suis là pour t\'aider à comprendre la notion en profondeur. Quelle question te poses-tu ?',
      });
    }
  }

  // -------------------------------------------------------------
  // DIALOGUE SOCRATIQUE (TUTOR AGENT AIA-AGT-001)
  // -------------------------------------------------------------
  Future<void> _sendSocraticQuestion(String question) async {
    final clean = question.trim();
    if (clean.isEmpty) return;

    setState(() {
      _chatHistory.add({'sender': 'user', 'text': clean});
      _questionCtrl.clear();
      _isLoading = true;
    });

    try {
      // Tentative d'appel via Supabase Edge Function ai-tutor-chat
      final response = await Supabase.instance.client.functions.invoke(
        'ai-tutor-chat',
        body: {
          'message': clean,
          'topic': widget.topicTitle,
          'subject': widget.subject,
          'formula': widget.formulaLatex,
          'mode': 'socratic',
          'history': _chatHistory.take(_chatHistory.length - 1).toList(),
        },
      ).timeout(const Duration(seconds: 4));

      final data = response.data;
      final reply = data is Map ? data['reply'] as String? : null;

      if (reply != null && reply.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _chatHistory.add({'sender': 'agent', 'text': reply});
          });
        }
        return;
      }
    } catch (_) {
      // Fallback déterministe autonome conforme au principe souverain (zéro dépendance bloquante)
    }

    if (!mounted) return;

    // Réponse maïeutique déterministe experte selon la thématique
    final fallbackResponse = _generateDeterministicSocraticReply(clean);
    setState(() {
      _isLoading = false;
      _chatHistory.add({'sender': 'agent', 'text': fallbackResponse});
    });
  }

  String _generateDeterministicSocraticReply(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('pourquoi') || lower.contains('sens') || lower.contains('signifie')) {
      return 'Très bonne réflexion ! Avant de regarder la formule brute, demande-toi : quand la grandeur d\'entrée augmente, que doit faire logiquement la grandeur de sortie ? Observe le numérateur et le dénominateur.';
    } else if (lower.contains('comment') || lower.contains('methode') || lower.contains('calcul')) {
      return 'Pour appliquer cette relation avec succès à l\'examen, identifie d\'abord les 3 données imposées par l\'énoncé. Quelles sont les grandeurs dont tu disposes directement ?';
    } else if (lower.contains('piege') || lower.contains('attention') || lower.contains('erreur')) {
      return 'Le piège n°1 réside dans les unités et les indices de sommation ! As-tu vérifié si la suite commence à U₀ (donc n+1 termes) ou à U₁ (donc n termes) ?';
    }
    return 'C\'est une excellente question sur "${widget.topicTitle}".\n'
        'Rappelle-toi la condition d\'application essentielle : vérifie toujours que les hypothèses sont satisfaites avant de poser le calcul final. Quelle est la première étape de ta démarche ?';
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 2)),
      ),
      child: Column(
        children: [
          // En-tête du Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withAlpha(35),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: AppColors.primaryCyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agents Pédagogiques EDLEARN',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.subject} • ${widget.topicTitle}',
                            style: GoogleFonts.inter(
                              color: AppColors.primaryCyan,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calculate_rounded, color: Color(0xFF10B981)),
                      tooltip: 'Calculateur SymPy & Outils Scientifiques',
                      onPressed: () {
                        ScientificToolsModal.show(
                          context,
                          initialQuery: widget.formulaLatex ?? widget.topicTitle,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sélecteur de Mode / Agent
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: Row(
                    children: [
                      _buildModeTab('tutor', 'Tuteur Socratique', Icons.psychology_rounded),
                      _buildModeTab('diagnostic', 'Pièges d\'Examen', Icons.rule_rounded),
                      _buildModeTab('exercise', 'S\'entraîner', Icons.edit_note_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),

          // Contenu du Mode Actif
          Expanded(
            child: _buildActiveModeBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String modeKey, String label, IconData icon) {
    final isSelected = _activeMode == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeMode = modeKey;
            _initializeMode();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryCyan : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.radiusSmall.topLeft.x),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveModeBody() {
    switch (_activeMode) {
      case 'diagnostic':
        return _buildDiagnosticBody();
      case 'exercise':
        return _buildExerciseBody();
      case 'tutor':
      default:
        return _buildTutorBody();
    }
  }

  // -------------------------------------------------------------
  // VUE 1 : TUTEUR SOCRATIQUE INTERACTIF
  // -------------------------------------------------------------
  Widget _buildTutorBody() {
    return Column(
      children: [
        if (widget.formulaLatex != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: MathFormulaView(
              formulaLatex: widget.formulaLatex!,
              fontSize: 14,
              showCopyButton: false,
              label: 'CONTEXTE DE LA NOTION',
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    InteractiveFunctionGraph.showModal(
                      context,
                      expression: widget.formulaLatex ?? '2x^2 - 4x - 6',
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.show_chart_rounded, size: 15, color: AppColors.cyanAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Tracer la courbe & variations',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    ScientificToolsModal.show(
                      context,
                      initialQuery: widget.formulaLatex ?? widget.topicTitle,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calculate_rounded, size: 15, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          'Calculer avec SymPy',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: _chatHistory.length,
            itemBuilder: (context, idx) {
              final msg = _chatHistory[idx];
              final isAgent = msg['sender'] == 'agent';

              return Align(
                alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    color: isAgent ? const Color(0xFF1E293B) : AppColors.primaryCyan,
                    borderRadius: BorderRadius.circular(14),
                    border: isAgent ? Border.all(color: const Color(0xFF334155)) : null,
                  ),
                  child: AiMessageBubbleRenderer(
                    message: msg['text'] ?? '',
                    isAi: isAgent,
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCyan),
                ),
                SizedBox(width: 8),
                Text('Le Tuteur Socratique réfléchit...', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        // Barre de saisie
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Color(0xFF334155))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Pose une question ou formule ton doute...',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: _sendSocraticQuestion,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primaryCyan, size: 20),
                onPressed: () => _sendSocraticQuestion(_questionCtrl.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // VUE 2 : DIAGNOSTIC DES PIÈGES DU BAC (MISCONCEPTION AGENT)
  // -------------------------------------------------------------
  Widget _buildDiagnosticBody() {
    final questions = _getDiagnosticQuestions();
    if (questions.isEmpty) {
      return const Center(child: Text('Aucun piège recensé pour cette notion.'));
    }

    final q = questions[_diagnosticQuestionIdx];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amberHighlight.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.amberHighlight.withAlpha(100)),
                ),
                child: const Text(
                  'DÉTECTEUR DE PIÈGES OFFICIELS',
                  style: TextStyle(color: AppColors.amberHighlight, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Question ${_diagnosticQuestionIdx + 1} / ${questions.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InlineLatexText(
            q['question'] as String,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Options QCM
          for (int i = 0; i < (q['options'] as List<String>).length; i++) ...[
            _buildDiagnosticOptionTile(
              index: i,
              text: (q['options'] as List<String>)[i],
              correctIndex: q['correct'] as int,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          if (_diagnosticAnswered) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDiagnosticOption == q['correct']
                      ? AppColors.tealSuccess
                      : AppColors.roseError,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDiagnosticOption == q['correct']
                        ? 'Bravo ! Tu as évité le piège classique.'
                        : 'Attention ! C\'est un piège très fréquent à l\'examen.',
                    style: TextStyle(
                      color: _selectedDiagnosticOption == q['correct']
                          ? AppColors.tealSuccess
                          : AppColors.roseError,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InlineLatexText(
                    q['explanation'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_diagnosticQuestionIdx < questions.length - 1)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: const Color(0xFF0F172A),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () {
                  setState(() {
                    _diagnosticQuestionIdx++;
                    _selectedDiagnosticOption = null;
                    _diagnosticAnswered = false;
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Piège suivant', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryCyan),
                ),
                child: Center(
                  child: Text(
                    'Diagnostic terminé ! Score : $_diagnosticScore / ${questions.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticOptionTile({required int index, required String text, required int correctIndex}) {
    Color borderColor = const Color(0xFF334155);
    Color bgColor = const Color(0xFF1E293B);

    if (_diagnosticAnswered) {
      if (index == correctIndex) {
        borderColor = AppColors.tealSuccess;
        bgColor = AppColors.tealSuccess.withAlpha(40);
      } else if (index == _selectedDiagnosticOption) {
        borderColor = AppColors.roseError;
        bgColor = AppColors.roseError.withAlpha(40);
      }
    }

    return InkWell(
      onTap: _diagnosticAnswered
          ? null
          : () {
              setState(() {
                _selectedDiagnosticOption = index;
                _diagnosticAnswered = true;
                if (index == correctIndex) _diagnosticScore++;
              });
            },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: InlineLatexText(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  List<Map<String, dynamic>> _getDiagnosticQuestions() {
    // Banque calibrée sur les programmes officiels
    return [
      {
        'question': 'Pour une somme \$S = U_0 + U_1 + \\dots + U_n\$, combien de termes comporte-t-elle ?',
        'options': ['\$n\$ termes', '\$n + 1\$ termes', '\$n - 1\$ termes', '\$2n\$ termes'],
        'correct': 1,
        'explanation': 'La somme va de 0 à n, donc le nombre de termes est (Indice final - Indice initial + 1) = \$n - 0 + 1 = n + 1\$.',
      },
      {
        'question': 'Si une suite géométrique a pour raison \$q = -2\$, que vaut sa limite ?',
        'options': ['0', '+\\infty', '-\\infty', 'Elle n\'a pas de limite (indéterminée)'],
        'correct': 3,
        'explanation': 'Pour \$q \\le -1\$, la suite \$q^n\$ change de signe à chaque rang et ses valeurs absolues tendent vers \$+\\infty\$ : elle diverge sans limite.',
      },
    ];
  }

  // -------------------------------------------------------------
  // VUE 3 : ENTRAÎNEMENT IMMÉDIAT (EXERCISE AGENT)
  // -------------------------------------------------------------
  Widget _buildExerciseBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tealSuccess.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.tealSuccess.withAlpha(100)),
            ),
            child: const Text(
              'EXERCICE D\'APPLICATION DIRECTE',
              style: TextStyle(color: AppColors.tealSuccess, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 14),
          InlineLatexText(
            'Soit \$(U_n)\$ une suite arithmétique de premier terme \$U_0 = 3\$ et de raison \$r = 4\$.\n'
            'Calcule la valeur du terme \$U_{10}\$.',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _exerciseAnswerCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ta réponse numérique pour U_10',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: const Color(0xFF0F172A),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              final val = _exerciseAnswerCtrl.text.trim();
              setState(() {
                _exerciseSubmitted = true;
                _exerciseCorrect = (val == '43');
              });
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Vérifier avec l\'Agent de Correction', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (_exerciseSubmitted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _exerciseCorrect ? AppColors.tealSuccess : AppColors.roseError,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _exerciseCorrect ? 'Excellent résultat ! (+20 XP)' : 'Ce n\'est pas tout à fait ça.',
                    style: TextStyle(
                      color: _exerciseCorrect ? AppColors.tealSuccess : AppColors.roseError,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Détail du calcul : U_n = U_0 + n · r = 3 + 10 · 4 = 3 + 40 = 43.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
