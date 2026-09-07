import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../core/rendering/ai_message_bubble_renderer.dart';
import '../../pedagogy/widgets/interactive_function_graph.dart';
import '../../pedagogy/widgets/photo_transcription_modal.dart';

class AiTutorChatScreen extends ConsumerStatefulWidget {
  const AiTutorChatScreen({super.key});

  @override
  ConsumerState<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends ConsumerState<AiTutorChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text':
          'Bonjour ! Je suis ton Tuteur Numérique, entièrement gratuit et sans limite. Pose-moi une question sur ton cours ou bloque sur un exercice, et je te guiderai pas-à-pas sans te donner la réponse toute faite !',
    },
  ];

  final List<String> _quickPrompts = [
    '📈 Étudie le polynôme P(x) = 2x² - 4x - 6 et trace sa courbe',
    '💡 Explique-moi le théorème des valeurs intermédiaires',
    '📝 Comment calculer le discriminant Δ ?',
    '⚠️ Quels sont les pièges classiques sur les nombres complexes ?',
    '🎯 Donne-moi un exemple guidé de suite géométrique',
    '🔬 Quelle est la méthode pour équilibrer une réaction redox ?',
  ];

  bool _isTyping = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return StudentPageContent(
      child: Column(
        children: [
          // En-tête du Tuteur IA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusMedium,
                    border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.cyanAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Tuteur Numérique',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.colors.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: AppRadius.radiusSmall,
                              border: Border.all(color: context.colors.accentEmerald.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'GRATUIT & ILLIMITÉ',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: context.colors.accentEmerald,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Programme ${profile?.className ?? 'Général'} • Maïeutique Pédagogique',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.cyanAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_messages.length > 1)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: context.colors.textMuted, size: 20),
                    tooltip: 'Nouvelle conversation',
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                        _messages.add({
                          'sender': 'ai',
                          'text': 'Nouvelle conversation démarrée ! Comment puis-je t\'aider sur tes cours ?',
                        });
                      });
                    },
                  ),
              ],
            ),
          ),

          // Barre horizontale de suggestions rapides (Quick Prompts)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(prompt),
                  backgroundColor: context.colors.card,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusFull,
                    side: BorderSide(color: context.colors.border),
                  ),
                  onPressed: () => _sendMessage(
                    prompt.replaceFirst(RegExp(r'^[^\s]+\s'), ''),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Liste des messages de la conversation
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAi = msg['sender'] == 'ai';

                return Row(
                  mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAi) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cyanAccent.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.cyanAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isAi ? context.colors.card : context.colors.accentIndigo,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(AppRadius.r16),
                            topRight: const Radius.circular(AppRadius.r16),
                            bottomLeft: Radius.circular(isAi ? AppRadius.r4 : AppRadius.r16),
                            bottomRight: Radius.circular(isAi ? AppRadius.r16 : AppRadius.r4),
                          ),
                          border: isAi ? Border.all(color: context.colors.border) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AiMessageBubbleRenderer(
                          message: msg['text'] ?? '',
                          isAi: isAi,
                        ),
                      ),
                    ),
                    if (!isAi) const SizedBox(width: 8),
                  ],
                );
              },
            ),
          ),

          // Indicateur de réflexion IA
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Le Tuteur Numérique réfléchit...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Zone de saisie du message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.document_scanner_rounded,
                      color: AppColors.cyanAccent,
                      size: 22,
                    ),
                    tooltip: 'Scanner une formule ou copie manuscrite (OCR)',
                    onPressed: () {
                      PhotoTranscriptionModal.show(
                        context,
                        onTranscription: (text) {
                          setState(() {
                            _msgCtrl.text = text;
                          });
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.show_chart_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                    tooltip: 'Tracer une courbe dynamique',
                    onPressed: () {
                      InteractiveFunctionGraph.showModal(
                        context,
                        expression: '2x^2 - 4x - 6',
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Pose ta question sur le cours ou un exercice...',
                        hintStyle: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: context.colors.card,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusFull,
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.radiusFull,
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.radiusFull,
                          borderSide: const BorderSide(color: AppColors.cyanAccent, width: 1.5),
                        ),
                      ),
                      onSubmitted: (text) => _sendMessage(text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.cyanAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      onPressed: () => _sendMessage(_msgCtrl.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildDeterministicTutorResponse(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('2x') || lower.contains('polyn') || lower.contains('courbe') || lower.contains('discriminant') || lower.contains('delta')) {
      return 'Voici l\'analyse méthodique du polynôme \$P(x) = 2x^2 - 4x - 6\$ :\n\n'
          '1. **Forme canonique** : En factorisant par 2, \$P(x) = 2(x^2 - 2x - 3) = 2(x - 1)^2 - 8\$. Le sommet de la parabole est \$S(1, -8)\$.\n\n'
          '2. **Discriminant** : \$\\Delta = b^2 - 4ac = (-4)^2 - 4(2)(-6) = 16 + 48 = 64 = 8^2 > 0\$.\n\n'
          '3. **Racines réelles** : Deux solutions distinctes \$x_1 = \\frac{4 - 8}{4} = -1\$ et \$x_2 = \\frac{4 + 8}{4} = 3\$.\n\n'
          '4. **Dérivée & Variations** : \$P\'(x) = 4x - 4\$. La fonction est strictement décroissante sur \$]-\\infty, 1]\$ puis strictement croissante sur \$[1, +\\infty[\$.\n\n'
          '👉 Tu peux cliquer sur les boutons ci-dessous pour tracer la courbe interactive et faire varier la tangente !';
    }
    if (lower.contains('valeurs intermédiaires') || lower.contains('tvi')) {
      return 'Le **Théorème des Valeurs Intermédiaires (TVI)** est fondamental :\n\n'
          'Si une fonction \$f\$ est continue sur un intervalle \$[a, b]\$, alors pour tout réel \$k\$ compris entre \$f(a)\$ et \$f(b)\$, il existe au moins un réel \$c \\in [a, b]\$ tel que \$f(c) = k\$.\n\n'
          'Si de plus \$f\$ est **strictement monotone**, cette solution \$c\$ est unique (Corollaire du TVI).';
    }
    if (lower.contains('complexe')) {
      return 'Pour les nombres complexes \$z = a + ib\$ :\n\n'
          '- Module : \$|z| = \\sqrt{a^2 + b^2}\$\n'
          '- Conjugué : \$\\bar{z} = a - ib\$\n'
          '- Forme trigonométrique : \$z = r(\\cos(\\theta) + i\\sin(\\theta)) = r e^{i\\theta}\$.\n\n'
          'Le piège classique à l\'examen est d\'oublier que \$\\sqrt{-1} = i\$ et que \$i^2 = -1\$.';
    }
    if (lower.contains('suite')) {
      return 'Pour une suite géométrique de premier terme \$u_0\$ et de raison \$q\$ :\n\n'
          '- Terme général : \$u_n = u_0 \\cdot q^n\$\n'
          '- Somme des termes : \$S_n = u_0 \\cdot \\frac{1 - q^{n+1}}{1 - q}\$ (pour \$q \\neq 1\$)\n'
          '- Limite : si \$-1 < q < 1\$, \$\\lim_{n \\to +\\infty} q^n = 0\$.';
    }
    return 'Je suis à tes côtés pour t\'expliquer ! Quelle est l\'étape précise de ton raisonnement où tu bloques ?';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final profile = ref.read(studentAuthProvider).activeProfile;

    setState(() {
      _messages.add({'sender': 'user', 'text': text.trim()});
      _msgCtrl.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-tutor-chat',
        body: {
          'message': text.trim(),
          'class_name': profile?.className,
          'history': _messages.take(_messages.length - 1).toList(),
        },
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;

      final data = response.data;
      final reply = data is Map ? data['reply'] as String? : null;

      setState(() {
        _isTyping = false;
        _messages.add({
          'sender': 'ai',
          'text': reply ?? _buildDeterministicTutorResponse(text),
        });
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'sender': 'ai',
          'text': _buildDeterministicTutorResponse(text),
        });
      });
      _scrollToBottom();
    }
  }
}
