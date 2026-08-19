import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

class SystemSettingsScreen extends ConsumerWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(notificationTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paramètres Système & Modèles de Notifications',
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Configuration du catalogue des notifications automatiques (Section 6.4 du CDC)',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                // Secrets réels (clé service_role, clés d'agrégateur Mobile Money, clés API IA) ne
                // doivent JAMAIS transiter par un champ de ce panneau client — ils sont gérés
                // uniquement via Supabase Dashboard > Edge Functions > Secrets (voir
                // 04_payment_webhook_security.md / 05_flutter_architecture.md). Un faux champ "Clé
                // API" ici ferait croire à tort qu'il configure quelque chose.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clés API & Secrets',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Les secrets (clé service_role, agrégateur Mobile Money, clés Claude/Gemini) ne se '
                              'configurent jamais depuis cette application admin — ils resteraient lisibles par '
                              'quiconque a accès au client. Configurez-les dans Supabase Dashboard → Edge Functions '
                              '→ Secrets.',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Catalogue des Modèles de Notifications (Cycle de vie)',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                templatesAsync.when(
                  data: (templates) {
                    if (templates.isEmpty) {
                      return Text('Aucun modèle de notification.', style: GoogleFonts.inter(color: AppTheme.textMuted));
                    }
                    return Column(
                      children: templates.map((tpl) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(tpl.eventKey,
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.accentBlue)),
                                  Row(
                                    children: [
                                      Text(tpl.channel, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.accentBlue),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Modifier',
                                        onPressed: () => _showEditTemplateModal(context, ref, tpl),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Titre : ${tpl.titleTemplate}',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              Text('Corps : ${tpl.bodyTemplate}',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateModal(BuildContext context, WidgetRef ref, NotificationTemplate tpl) {
    final titleCtrl = TextEditingController(text: tpl.titleTemplate);
    final bodyCtrl = TextEditingController(text: tpl.bodyTemplate);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          title: AppDialogTitle(
            icon: Icons.edit_rounded,
            text: 'Modifier : ${tpl.eventKey}',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Titre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Corps du message'),
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
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateNotificationTemplate(
                          tpl.id,
                          titleTemplate: titleCtrl.text.trim(),
                          bodyTemplate: bodyCtrl.text.trim(),
                        );
                        ref.invalidate(notificationTemplatesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(backgroundColor: AppTheme.accentRose, content: Text('Erreur: $e')),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
