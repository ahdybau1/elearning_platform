import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §9 du cahier des charges. Entièrement réel : création et lecture passent par `support_tickets`,
/// déjà protégé par RLS (owns_account) — aucune donnée fictive nécessaire, contrairement aux autres
/// pages ajoutées dans cette même passe.
class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(studentAuthProvider).account;

    return account == null
        ? const Center(child: CircularProgressIndicator())
        : StudentPageContent(child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: StudentScreenHeader(
                    title: 'Messagerie & Support',
                    trailing: IconButton(
                      tooltip: 'Nouveau ticket',
                      icon: Icon(Icons.add_circle_outline_rounded, color: context.colors.accentPrimary),
                      onPressed: () => _showNewTicketDialog(context, account.id),
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final ticketsAsync = ref.watch(supportTicketsProvider(account.id));
                      return ticketsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: Colors.red))),
                        data: (tickets) {
                          if (tickets.isEmpty) return _emptyState(context, account.id);
                          return ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: tickets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _buildTicketCard(tickets[index]),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ));
  }

  Widget _emptyState(BuildContext context, String accountId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent_rounded, size: 46, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text('Aucun ticket pour le moment', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            const SizedBox(height: 6),
            Text('Une question, un problème de paiement ou un bug ? Contactez l\'administration.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentPrimary, foregroundColor: Colors.black),
              onPressed: () => _showNewTicketDialog(context, accountId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer un ticket', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final statusColor = switch (ticket.status) {
      'ouvert' => context.colors.accentAmber,
      'en_cours' => context.colors.accentIndigo,
      'repondu' => context.colors.accentEmerald,
      _ => context.colors.textMuted,
    };
    final statusLabel = switch (ticket.status) {
      'ouvert' => 'Ouvert',
      'en_cours' => 'En cours',
      'repondu' => 'Répondu',
      _ => 'Fermé',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(ticket.subject, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(ticket.description, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (ticket.replyMessage?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.support_agent_rounded, size: 14, color: context.colors.accentEmerald),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ticket.replyMessage!, style: GoogleFonts.inter(fontSize: 12, color: Colors.white))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(_categoryLabel(ticket.category), style: GoogleFonts.inter(fontSize: 10, color: context.colors.textMuted)),
        ],
      ),
    );
  }

  String _categoryLabel(String category) => switch (category) {
        'paiement' => 'Paiement',
        'technique' => 'Technique',
        'contenu' => 'Contenu',
        _ => 'Autre',
      };

  void _showNewTicketDialog(BuildContext context, String accountId) {
    final subjectCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String category = 'technique';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text('Nouveau Ticket', style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _catChip('technique', 'Technique', category, (v) => setDialogState(() => category = v)),
                      _catChip('paiement', 'Paiement', category, (v) => setDialogState(() => category = v)),
                      _catChip('contenu', 'Contenu', category, (v) => setDialogState(() => category = v)),
                      _catChip('autre', 'Autre', category, (v) => setDialogState(() => category = v)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: subjectCtrl,
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Objet',
                      labelStyle: TextStyle(color: context.colors.textSecondary),
                      filled: true,
                      fillColor: context.colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descriptionCtrl,
                    maxLines: 4,
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: context.colors.textSecondary),
                      filled: true,
                      fillColor: context.colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: context.colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentPrimary),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await ref.read(studentSupabaseServiceProvider).createSupportTicket(
                              accountId: accountId,
                              category: category,
                              subject: subjectCtrl.text.trim(),
                              description: descriptionCtrl.text.trim(),
                            );
                        ref.invalidate(supportTicketsProvider(accountId));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Envoyer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String value, String label, String selected, ValueChanged<String> onSelected) {
    final isSel = value == selected;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
      selected: isSel,
      onSelected: (_) => onSelected(value),
      selectedColor: context.colors.accentPrimary.withOpacity(0.2),
      backgroundColor: context.colors.surface,
      labelStyle: TextStyle(color: isSel ? context.colors.accentPrimary : context.colors.textPrimary),
    );
  }
}
