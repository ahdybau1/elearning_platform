import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/community_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

const _statusFilters = <String?, String>{
  null: 'Tous',
  'ouvert': 'Ouvert',
  'en_cours': 'En cours',
  'repondu': 'Répondu',
  'ferme': 'Fermé',
};

const _requesterFilters = <String?, String>{
  null: 'Tous',
  'eleve': 'Élève',
  'parent': 'Parent',
};

const _categoryLabels = <String, String>{
  'paiement': 'Paiement',
  'technique': 'Technique',
  'contenu': 'Contenu',
  'autre': 'Autre',
};

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  String? _statusFilter;
  String? _requesterFilter;

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(supportTicketsStreamProvider(_statusFilter));
    final accountsAsync = ref.watch(accountsProvider(null));
    final accountNames = <String, String>{
      for (final account in accountsAsync.valueOrNull ?? <Account>[])
        account.id: '${account.firstName} ${account.lastName}',
    };
    final parentAccountsAsync = ref.watch(parentAccountsProvider(null));
    final parentAccountNames = <String, String>{
      for (final parent in parentAccountsAsync.valueOrNull ?? <ParentAccount>[])
        parent.id: '${parent.firstName} ${parent.lastName} (parent)',
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column plutôt que Row(Expanded(titre), badge) : le badge comme simple frère de
          // l'Expanded affamait quand même le titre sur mobile (retour utilisateur réel, capture
          // d'écran, 2026-08-30 — le premier correctif avec Expanded seul ne suffisait pas).
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
              const SizedBox(height: 10),
              ticketsAsync.when(
                data: (tickets) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tickets.length} ticket${tickets.length > 1 ? 's' : ''} affiché${tickets.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterGroup(
                  label: 'Statut',
                  options: _statusFilters,
                  selected: _statusFilter,
                  onSelected: (v) => setState(() => _statusFilter = v),
                ),
                _buildFilterGroup(
                  label: 'Demandeur',
                  options: _requesterFilters,
                  selected: _requesterFilter,
                  onSelected: (v) => setState(() => _requesterFilter = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: ticketsAsync.when(
              data: (allTickets) {
                final tickets = _requesterFilter == null
                    ? allTickets
                    : allTickets.where((t) => t.requesterType == _requesterFilter).toList();

                if (tickets.isEmpty) {
                  return Center(
                    child: Text('Aucun ticket de support pour ce filtre.',
                        style: GoogleFonts.inter(color: AppTheme.textMuted)),
                  );
                }
                return ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (context, idx) {
                    final tick = tickets[idx];
                    final isParent = tick.requesterType == 'parent';
                    final isResolved = tick.status == 'ferme';
                    final requesterName = tick.accountId != null
                        ? (accountNames[tick.accountId] ?? 'Compte inconnu')
                        : (parentAccountNames[tick.parentAccountId] ?? 'Compte parent inconnu');

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
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _categoryLabels[tick.category] ?? tick.category,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    _buildStatusBadge(tick.status),
                                    Text(requesterName,
                                        style: GoogleFonts.outfit(
                                            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                          // Wrap plutôt que Row : le texte d'assignation (nom potentiellement long)
                          // + les boutons ne tenaient pas côte à côte sur mobile — ils passent
                          // maintenant à la ligne au lieu de déborder (retour utilisateur réel,
                          // 2026-08-30).
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 8,
                            children: [
                              Text(
                                tick.assignedTo == null
                                    ? 'Non assigné'
                                    : 'Assigné à : ${accountNames[tick.assignedTo] ?? tick.assignedTo}',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                              ),
                              Wrap(
                                spacing: 10,
                                children: [
                                  if (!isResolved && tick.assignedTo == null)
                                    OutlinedButton.icon(
                                      onPressed: () => _assignToMe(context, tick),
                                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                      label: const Text('S\'assigner ce ticket'),
                                    ),
                                  if (!isResolved)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                                      onPressed: () => _showReplyModal(context, ref, tick, requesterName),
                                      icon: const Icon(Icons.reply_rounded, size: 16),
                                      label: const Text('Répondre au Ticket'),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Ticket Résolu ✓',
                                        style: GoogleFonts.inter(
                                            fontSize: 12, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
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

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'ouvert':
        color = AppTheme.accentRose;
        break;
      case 'en_cours':
        color = AppTheme.accentAmber;
        break;
      case 'repondu':
        color = AppTheme.accentCyan;
        break;
      default:
        color = AppTheme.accentEmerald;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        _statusFilters[status] ?? status,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildFilterGroup({
    required String label,
    required Map<String?, String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label : ',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          children: options.entries.map((e) {
            final isSel = selected == e.key;
            return ChoiceChip(
              selected: isSel,
              showCheckmark: false,
              label: Text(e.value),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : AppTheme.textMuted,
              ),
              selectedColor: AppTheme.accentBlue,
              backgroundColor: AppTheme.primaryDark,
              onSelected: (_) => onSelected(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _assignToMe(BuildContext context, SupportTicket tick) async {
    final adminId = ref.read(authProvider).valueOrNull?.id;
    if (adminId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(supabaseServiceProvider).assignTicket(tick.id, adminId);
      ref.invalidate(supportTicketsStreamProvider(_statusFilter));
      messenger.showSnackBar(
        const SnackBar(backgroundColor: AppTheme.accentEmerald, content: Text('Ticket assigné à vous-même.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur : $e')));
    }
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
                        ref.invalidate(supportTicketsStreamProvider(_statusFilter));
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
