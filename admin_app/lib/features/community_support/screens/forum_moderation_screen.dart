import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/community_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class ForumModerationScreen extends ConsumerWidget {
  const ForumModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(flaggedPostsProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${postsAsync.valueOrNull?.length ?? 0} signalements à traiter',
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
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun signalement en attente de modération.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, idx) {
                    final post = posts[idx];
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
                            children: [
                              Expanded(
                                child: Text(
                                  'Signalement : ${post.authorDisplayName}',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(post.createdAt.toLocal()),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Consumer(
                            builder: (context, ref, _) {
                              final nodeAsync = ref.watch(nodeByIdProvider(post.threadClassNodeId));
                              final className = nodeAsync.valueOrNull?.name;
                              return Text(
                                [
                                  ?post.threadTitle,
                                  ?className,
                                  post.flagReason ?? 'Signalé automatiquement',
                                ].join(' • '),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.accentRose,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Message masqué : "${post.content}"',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final service = ref.read(supabaseServiceProvider);
                                  try {
                                    await service.dismissFlag(post.id);
                                    ref.invalidate(flaggedPostsProvider);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppTheme.accentEmerald,
                                        content: Text('Message rétabli sur le forum.'),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                                    );
                                  }
                                },
                                child: const Text('Rétablir le Message (Faux Positif)'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
                                onPressed: () => _showDeleteConfirmation(context, ref, post),
                                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                                label: const Text('Confirmer la Suppression'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose))),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, ForumPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.delete_forever_rounded,
          iconColor: AppTheme.accentRose,
          text: 'Supprimer ce message définitivement ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'IRRÉVERSIBLE : le message de ${post.authorDisplayName} sera définitivement supprimé du forum. '
          'Un avertissement n\'est pas envoyé automatiquement — contactez l\'élève séparément si nécessaire.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(supabaseServiceProvider);
              try {
                await service.deleteForumPost(post.id);
                ref.invalidate(flaggedPostsProvider);
                messenger.showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Message définitivement supprimé.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
