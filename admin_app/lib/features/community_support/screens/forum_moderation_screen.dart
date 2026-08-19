import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/data_providers.dart';

class ForumModerationScreen extends ConsumerStatefulWidget {
  const ForumModerationScreen({super.key});

  @override
  ConsumerState<ForumModerationScreen> createState() => _ForumModerationScreenState();
}

class _ForumModerationScreenState extends ConsumerState<ForumModerationScreen> {
  final List<Map<String, dynamic>> _flaggedPosts = [
    {
      'id': 'post-501',
      'author': 'Élève A (Profil 3e)',
      'class': 'Classe de 3ème • Mathématiques',
      'content':
          'Le prof de math est v222m3nt un i.d.i.o.t il donne trop de devoirs...',
      'flagReason':
          'Signalé par camarade + AI Risk Score élevé (Contournement orthographique)',
      'aiScore': '94% Risque Propos Insultants',
      'autoHidden': true,
      'time': 'Il y a 15 min',
    },
    {
      'id': 'post-502',
      'author': 'Élève B (Profil Tle C)',
      'content': 'Lien externe suspect de triche pour le devoir de physique',
      'flagReason': 'Lien suspect externe détecté par le filtre anti-spam',
      'aiScore': '88% Lien non vérifié',
      'autoHidden': true,
      'time': 'Il y a 45 min',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modération du Forum d\'Entraide',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Protection des mineurs : Masquage automatique préventif via Agent IA (Gemini) + Décision du Modérateur',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_flaggedPosts.length} signalements à traiter',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentRose,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _flaggedPosts.isEmpty
                ? Center(
                    child: Text(
                      'Aucun signalement en attente de modération.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _flaggedPosts.length,
                    itemBuilder: (context, idx) {
                      final post = _flaggedPosts[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.accentRose),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Signalement : ${post['author']}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  post['time'],
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${post['class'] ?? 'Forum'} • ${post['flagReason']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentRose,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Message masqué : "${post['content']}"',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final service = ref.read(supabaseServiceProvider);
                                    await service.dismissFlag(post['id']);
                                    setState(() => _flaggedPosts.removeAt(idx));
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppTheme.accentEmerald,
                                        content: Text('Message rétabli sur le forum.'),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Rétablir le Message (Faux Positif)',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentRose,
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final service = ref.read(supabaseServiceProvider);
                                    await service.deleteForumPost(post['id']);
                                    setState(() => _flaggedPosts.removeAt(idx));
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppTheme.accentRose,
                                        content: Text('Message définitivement supprimé.'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                                  label: const Text('Confirmer la Suppression'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
