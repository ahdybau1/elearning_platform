import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/community_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsStreamProvider);
    final accountsAsync = ref.watch(accountsProvider(null));
    final accountNames = <String, String>{
      for (final account in accountsAsync.valueOrNull ?? <Account>[])
        account.id: '${account.firstName} ${account.lastName}',
    };

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
                    'Centre de Traitement des Tickets Support',
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distinction explicite des requêtes venant des élèves vs des parents payeurs',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ],
              ),
              ticketsAsync.when(
                data: (tickets) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tickets.where((t) => t.status != 'ferme').length} tickets actifs',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ticketsAsync.when(
              data: (tickets) {
                if (tickets.isEmpty) {
                  return Center(
                    child: Text('Aucun ticket de support pour le moment.',
                        style: GoogleFonts.inter(color: AppTheme.textMuted)),
                  );
                }
                return ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (context, idx) {
                    final tick = tickets[idx];
                    final isParent = tick.requesterType == 'parent';
                    final isResolved = tick.status == 'ferme';
                    final requesterName = accountNames[tick.accountId] ?? 'Compte inconnu';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isResolved ? AppTheme.accentEmerald.withValues(alpha: 0.4) : AppTheme.primaryBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isParent
                                          ? AppTheme.accentAmber.withValues(alpha: 0.15)
                                          : AppTheme.accentBlue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'TICKET ${tick.requesterType.toUpperCase()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isParent ? AppTheme.accentAmber : AppTheme.accentBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(requesterName,
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              Text(
                                tick.createdAt.toLocal().toString().split('.').first,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Sujet : ${tick.subject}',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(tick.description, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isResolved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Ticket Résolu ✓',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                                  onPressed: () => _showReplyModal(context, ref, tick, requesterName),
                                  icon: const Icon(Icons.reply_rounded, size: 16),
                                  label: const Text('Répondre au Ticket'),
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

  void _showReplyModal(BuildContext context, WidgetRef ref, SupportTicket tick, String requesterName) {
    final responseController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.reply_rounded,
            text: 'Répondre à $requesterName',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sujet: ${tick.subject}',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: responseController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Saisissez votre réponse explicative ou solution au client...',
                    ),
                  ),
                ],
              ),
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
                      final response = responseController.text.trim();
                      if (response.isEmpty) return;

                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateTicketStatus(tick.id, 'ferme', replyMessage: response);

                        ref.invalidate(openTicketsCountProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accentEmerald,
                              content: Text(
                                'Réponse transmise à $requesterName. Ticket marqué comme résolu.',
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer & Clôturer'),
            ),
          ],
        ),
      ),
    );
  }
}
