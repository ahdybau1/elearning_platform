import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);

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
                    'Gestion des Bannières d\'Annonces',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diffusion de messages ciblés par pays/classe avec affichage temporisé automatique',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddAnnouncementModal(context),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Publier une Annonce'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: announcementsAsync.when(
              data: (announcements) {
                if (announcements.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune bannière d\'annonce active.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (context, idx) {
                    final ann = announcements[idx];
                    final isWarning = ann.urgency == 'warning' || ann.urgency == 'urgent';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isWarning ? AppTheme.accentAmber : AppTheme.primaryBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isWarning
                                ? AppTheme.accentAmber.withValues(alpha: 0.15)
                                : AppTheme.accentBlue.withValues(alpha: 0.15),
                            child: Icon(
                              isWarning ? Icons.warning_rounded : Icons.campaign_rounded,
                              color: isWarning ? AppTheme.accentAmber : AppTheme.accentBlue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ann.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ann.message,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Urgence : ${ann.urgency.toUpperCase()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.accentRose,
                            ),
                            onPressed: () async {
                              final service = ref.read(supabaseServiceProvider);
                              await service.deleteAnnouncement(ann.id);
                              ref.invalidate(announcementsStreamProvider);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );

              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAnnouncementModal(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String urgency = 'info';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.campaign_rounded,
            text: 'Publier une Bannière d\'Annonce',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Titre de l\'annonce'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Message de l\'annonce'),
                ),
                const SizedBox(height: 16),
                // ignore: deprecated_member_use
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: urgency,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Niveau d\'urgence'),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Informatif (Bleu)')),
                    DropdownMenuItem(value: 'warning', child: Text('Avertissement (Orange)')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent (Rouge)')),
                  ],
                  onChanged: (v) => setModalState(() => urgency = v ?? 'info'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final message = messageController.text.trim();
                      if (title.isEmpty || message.isEmpty) return;

                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createAnnouncement(
                          title: title,
                          message: message,
                          urgency: urgency,
                          startDate: DateTime.now(),
                          endDate: DateTime.now().add(const Duration(days: 30)),
                        );

                        ref.invalidate(announcementsStreamProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text('Annonce "$title" publiée avec succès !', style: GoogleFonts.inter(color: Colors.white)),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentRose,
                              content: Text('Erreur: $e', style: GoogleFonts.inter(color: Colors.white)),
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Publier L\'Annonce'),
            ),
          ],
        ),
      ),
    );
  }
}
