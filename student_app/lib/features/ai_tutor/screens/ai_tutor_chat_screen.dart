import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';

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

    return StudentPageContent(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
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
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final profile = ref.read(studentAuthProvider).activeProfile;

    setState(() {
      _messages.add({'sender': 'user', 'text': text.trim()});
      _msgCtrl.clear();
      _isTyping = true;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-tutor-chat',
        body: {
          'message': text.trim(),
          'class_name': profile?.className,
          'history': _messages.take(_messages.length - 1).toList(),
        },
      );

      if (!mounted) return;

      final data = response.data;
      final reply = data is Map ? data['reply'] as String? : null;
      final error = data is Map ? data['error'] as String? : null;

      setState(() {
        _isTyping = false;
        _messages.add({
          'sender': 'ai',
          // Jamais de fausse réponse en secours : une panne réelle du fournisseur reste visible.
          'text': reply ?? error ?? 'Le Tuteur IA est momentanément indisponible, réessayez dans un instant.',
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({'sender': 'ai', 'text': 'Le Tuteur IA est momentanément indisponible, réessayez dans un instant.'});
      });
    }
  }
}
