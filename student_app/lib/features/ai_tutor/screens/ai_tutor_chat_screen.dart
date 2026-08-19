import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';

class AiTutorChatScreen extends ConsumerStatefulWidget {
  const AiTutorChatScreen({super.key});

  @override
  ConsumerState<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends ConsumerState<AiTutorChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text': 'Bonjour ! Je suis ton Tuteur IA personnel pour ton programme officiel. Pose-moi une question sur ton cours ou bloque sur un exercice, et je te guiderai pas-à-pas sans te donner la réponse toute faite !',
    },
  ];

  final List<String> _quickPrompts = [
    '💡 Explique-moi le théorème des valeurs intermédiaires',
    r'📝 Comment calculer le discriminant \Delta ?',
    '⚠️ Quels sont les pièges classiques sur les nombres complexes ?',
    '🎯 Donne-moi un exemple guidé de dissertation',
  ];

  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: StudentTheme.accentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: StudentTheme.accentCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuteur IA Contextualisé',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                ),
                Text(
                  'Programme ${profile?.className ?? ''} • Maïeutique Pédagogique',
                  style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.accentCyan),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Prompts Horizontal Bar
          Container(
            height: 48,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(prompt),
                  backgroundColor: StudentTheme.cardDark,
                  labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: StudentTheme.borderDark),
                  ),
                  onPressed: () => _sendMessage(prompt.replaceFirst(RegExp(r'^[^\s]+\s'), '')),
                );
              },
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAi = msg['sender'] == 'ai';

                return Row(
                  mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAi) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StudentTheme.accentCyan.withOpacity(0.2),
                          border: Border.all(color: StudentTheme.accentCyan),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: StudentTheme.accentCyan, size: 16),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isAi ? StudentTheme.cardDark : StudentTheme.accentIndigo,
                          borderRadius: BorderRadius.circular(16),
                          border: isAi ? Border.all(color: StudentTheme.borderDark) : null,
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (!isAi) const SizedBox(width: 10),
                  ],
                );
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: StudentTheme.accentCyan),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Le Tuteur IA réfléchit...',
                    style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
                  ),
                ],
              ),
            ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: StudentTheme.surfaceDark,
              border: Border(top: BorderSide(color: StudentTheme.borderDark)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Pose ta question sur le cours ou un exercice...',
                      hintStyle: GoogleFonts.inter(color: StudentTheme.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: StudentTheme.cardDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: StudentTheme.borderDark),
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: StudentTheme.accentPrimary),
                  onPressed: () => _sendMessage(_msgCtrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text.trim()});
      _msgCtrl.clear();
      _isTyping = true;
    });

    // Simulated contextual AI tutor reasoning based on Section 8 (Maïeutique)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        String response = 'Pour bien aborder cette notion, commençons par identifier les hypothèses de base : quelles sont les données fournies dans ton énoncé ?';

        if (text.toLowerCase().contains('discriminant') || text.toLowerCase().contains('delta')) {
          response = r"Pour calculer le discriminant \Delta = b^2 - 4ac, commence par écrire ton équation sous la forme standard ax^2 + bx + c = 0. Quels sont tes coefficients a, b et c ?";
        } else if (text.toLowerCase().contains('complexe') || text.toLowerCase().contains('module')) {
          response = r"Rappelle-toi de la définition : pour z = a + ib, le module est |z| = \sqrt{a^2 + b^2}. Attention au piège classique : on ne met jamais i sous la racine carrée !";
        } else if (text.toLowerCase().contains('valeurs intermédiaires') || text.toLowerCase().contains('tvi')) {
          response = 'Le Théorème des Valeurs Intermédiaires exige deux conditions majeures : 1. La continuité de la fonction sur [a, b]. 2. La stricte monotonie si l\'on veut l\'unicité de la solution. As-tu vérifié si ta fonction est strictement croissante ou décroissante ?';
        }

        setState(() {
          _isTyping = false;
          _messages.add({'sender': 'ai', 'text': response});
        });
      }
    });
  }

}
