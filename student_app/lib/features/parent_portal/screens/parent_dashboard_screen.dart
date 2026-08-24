import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/parent_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §17 du cahier des charges — Espace Parent réel : identité et données proviennent de
/// [parentAuthProvider] (session Supabase Auth dédiée au compte parent, `parent_accounts`), jamais
/// de `studentAuthProvider` (l'ancien bug affichait le compte ÉLÈVE actuellement connecté sur cet
/// appareil, pas le parent). Navigation complète « en tant que » l'élève dans cours/forum/IA reste
/// hors périmètre de cette passe (lecture seule ici) — voir l'addendum daté dans
/// docs/cahier_des_charges.md.
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentState = ref.watch(parentAuthProvider);

    if (!parentState.isAuthenticated) {
      return StudentPageContent(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.family_restroom_rounded, size: 46, color: context.colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  parentState.errorMessage ?? 'Aucune session parent active.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final parent = parentState.account!;
    final transactionsAsync = ref.watch(parentTransactionsProvider);

    return StudentPageContent(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentScreenHeader(
              title: 'Espace Parent & Suivi Scolaire',
              subtitle: 'Bienvenue, ${parent.firstName} — suivi individuel et communication avec l\'administration.',
            ),
            const SizedBox(height: 20),
            // Parent Account Info Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.accentAmber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_user_rounded, color: context.colors.accentAmber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${parent.firstName} ${parent.lastName} • ${parent.email}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.colors.textPrimary, fontSize: 14),
                        ),
                        Text(
                          parent.phone.isNotEmpty ? parent.phone : 'Téléphone non renseigné',
                          style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Support & informations légales',
                    icon: Icon(Icons.settings_outlined, color: context.colors.textSecondary),
                    onPressed: () => _showSupportAndLegalSheet(context, ref),
                  ),
                  IconButton(
                    tooltip: 'Se déconnecter (Espace Parent)',
                    icon: Icon(Icons.logout_rounded, color: context.colors.textSecondary),
                    onPressed: () async {
                      await ref.read(parentAuthProvider.notifier).signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Suivi Individuel des Enfants',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 14),

            if (parentState.children.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: context.colors.textMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aucun profil élève n\'est encore lié à ce compte parent. Contactez l\'administration pour établir le rattachement.',
                        style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...parentState.children.map((child) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
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
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: StudentTheme.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    child.displayName.isNotEmpty ? child.displayName[0].toUpperCase() : '?',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.displayName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.colors.textPrimary, fontSize: 15),
                                  ),
                                  Text(
                                    '${child.className} • Année ${child.schoolYear}',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: child.hasActiveSubscription
                                  ? context.colors.accentEmerald.withOpacity(0.15)
                                  : context.colors.accentRose.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              child.hasActiveSubscription ? 'Pass ${child.subscriptionTier.toUpperCase()}' : 'Accès Gratuit',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: child.hasActiveSubscription ? context.colors.accentEmerald : context.colors.accentRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // La gamification (streak, points XP) et les moyennes de quiz n'ont pas encore
                      // de table réelle en base (voir docs/cahier_des_charges.md §14) — retiré plutôt
                      // que d'afficher des chiffres inventés. La navigation complète « en tant que »
                      // l'élève (cours/forum/IA) reste une suite dédiée, hors périmètre de cette passe.
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),

            // Receipts / Payment History Section
            Text(
              'Historique & Reçus de Paiement',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: transactionsAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
                error: (err, _) => Text('Erreur : $err', style: GoogleFonts.inter(fontSize: 12, color: context.colors.accentRose)),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Text(
                      'Aucun paiement enregistré pour le moment.',
                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < transactions.length; i++) ...[
                        if (i > 0) Divider(color: context.colors.border),
                        _buildPaymentHistoryRow(context, transactions[i]),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showNewTicketDialog(context, ref),
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: const Text('Contacter l\'administration'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.accentPrimary,
                side: BorderSide(color: context.colors.accentPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryRow(BuildContext context, ParentTransaction tx) {
    final dateStr = '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$dateStr • ${tx.operator}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            ],
          ),
          Text('${tx.amount.toStringAsFixed(0)} FCFA', style: GoogleFonts.firaCode(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.accentEmerald)),
        ],
      ),
    );
  }

  void _showNewTicketDialog(BuildContext context, WidgetRef ref) {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'paiement';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text('Contacter l\'administration', style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in ['paiement', 'technique', 'contenu', 'autre'])
                      ChoiceChip(
                        label: Text(c),
                        selected: category == c,
                        onSelected: (_) => setDialogState(() => category = c),
                        selectedColor: context.colors.accentPrimary.withOpacity(0.2),
                        backgroundColor: context.colors.surface,
                        labelStyle: TextStyle(color: category == c ? context.colors.accentPrimary : context.colors.textPrimary, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Objet',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
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
                      if (subjectCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      final error = await ref.read(parentAuthProvider.notifier).createSupportTicket(
                            category: category,
                            subject: subjectCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error != null ? 'Erreur : $error' : 'Ticket envoyé — l\'administration vous répondra.')),
                        );
                      }
                    },
              child: const Text('Envoyer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportAndLegalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final settingsAsync = ref.watch(appSettingsProvider);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: settingsAsync.when(
              data: (settings) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Support & Informations Légales',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                  const SizedBox(height: 16),
                  if (settings.supportEmail?.isNotEmpty == true)
                    _infoRow(context, Icons.email_outlined, 'Email', settings.supportEmail!),
                  if (settings.supportPhone?.isNotEmpty == true)
                    _infoRow(context, Icons.phone_outlined, 'Téléphone', settings.supportPhone!),
                  if (settings.supportWhatsappLink?.isNotEmpty == true)
                    _infoRow(context, Icons.chat_outlined, 'WhatsApp', settings.supportWhatsappLink!),
                  if (settings.termsUrl?.isNotEmpty == true)
                    _infoRow(context, Icons.description_outlined, 'CGU', settings.termsUrl!),
                  if (settings.privacyPolicyUrl?.isNotEmpty == true)
                    _infoRow(context, Icons.privacy_tip_outlined, 'Confidentialité', settings.privacyPolicyUrl!),
                  if (settings.legalNoticeUrl?.isNotEmpty == true)
                    _infoRow(context, Icons.gavel_outlined, 'Mentions légales', settings.legalNoticeUrl!),
                  if ((settings.supportEmail?.isEmpty ?? true) &&
                      (settings.supportPhone?.isEmpty ?? true) &&
                      (settings.supportWhatsappLink?.isEmpty ?? true) &&
                      (settings.termsUrl?.isEmpty ?? true) &&
                      (settings.privacyPolicyUrl?.isEmpty ?? true) &&
                      (settings.legalNoticeUrl?.isEmpty ?? true))
                    Text('Aucune information de support renseignée par l\'administration pour le moment.',
                        style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary)),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Text('Erreur: $err', style: GoogleFonts.inter(color: Colors.redAccent)),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.colors.accentAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted)),
                SelectableText(value, style: GoogleFonts.inter(fontSize: 13, color: context.colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
