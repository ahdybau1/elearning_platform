import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/system_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog_title.dart';

const _availableLanguages = <String, String>{
  'fr': 'Français',
  'en': 'Anglais',
  'ar': 'Arabe',
  'pt': 'Portugais',
  'es': 'Espagnol',
};

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
            'Paramètres Système',
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Configuration globale de l\'application admin et de l\'application élève (Section 15 du CDC)',
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
                              'Les secrets (clé service_role, agrégateur Mobile Money, clé Gemini) ne se '
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
                const SizedBox(height: 28),

                Text(
                  'Configuration Générale (Admin + Application Élève)',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const _GeneralSettingsForm(),

                const SizedBox(height: 28),
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
    String? formError;
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
                  if (formError != null) ...[
                    const SizedBox(height: 12),
                    Text(formError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                  ],
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
                      final title = titleCtrl.text.trim();
                      final body = bodyCtrl.text.trim();
                      if (title.isEmpty || body.isEmpty) {
                        setModalState(() => formError = 'Le titre et le corps du message sont obligatoires.');
                        return;
                      }
                      setModalState(() {
                        formError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateNotificationTemplate(
                          tpl.id,
                          titleTemplate: title,
                          bodyTemplate: body,
                        );
                        ref.invalidate(notificationTemplatesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          formError = '$e';
                        });
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

class _GeneralSettingsForm extends ConsumerStatefulWidget {
  const _GeneralSettingsForm();

  @override
  ConsumerState<_GeneralSettingsForm> createState() => _GeneralSettingsFormState();
}

class _GeneralSettingsFormState extends ConsumerState<_GeneralSettingsForm> {
  AppSettings? _loadedFrom;
  final _appNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _supportWhatsappCtrl = TextEditingController();
  final _termsUrlCtrl = TextEditingController();
  final _privacyUrlCtrl = TextEditingController();
  final _legalUrlCtrl = TextEditingController();
  final _maintenanceMessageCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  bool _maintenanceMode = false;
  Set<String> _enabledLanguages = {'fr'};
  bool _isSaving = false;
  String? _saveError;

  @override
  void dispose() {
    _appNameCtrl.dispose();
    _taglineCtrl.dispose();
    _supportEmailCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _supportWhatsappCtrl.dispose();
    _termsUrlCtrl.dispose();
    _privacyUrlCtrl.dispose();
    _legalUrlCtrl.dispose();
    _maintenanceMessageCtrl.dispose();
    _minVersionCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(AppSettings s) {
    _loadedFrom = s;
    _appNameCtrl.text = s.appName;
    _taglineCtrl.text = s.tagline ?? '';
    _supportEmailCtrl.text = s.supportEmail ?? '';
    _supportPhoneCtrl.text = s.supportPhone ?? '';
    _supportWhatsappCtrl.text = s.supportWhatsappLink ?? '';
    _termsUrlCtrl.text = s.termsUrl ?? '';
    _privacyUrlCtrl.text = s.privacyPolicyUrl ?? '';
    _legalUrlCtrl.text = s.legalNoticeUrl ?? '';
    _maintenanceMessageCtrl.text = s.maintenanceMessage ?? '';
    _minVersionCtrl.text = s.minSupportedAppVersion ?? '';
    _maintenanceMode = s.maintenanceMode;
    _enabledLanguages = s.enabledLanguages.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        if (_loadedFrom == null || _loadedFrom!.id != settings.id) {
          _loadFrom(settings);
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Identité de l\'application'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_appNameCtrl, 'Nom de l\'application')),
                  const SizedBox(width: 16),
                  Expanded(child: _field(_taglineCtrl, 'Slogan (tagline)')),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Contact Support (élèves & parents)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_supportEmailCtrl, 'Email de support')),
                  const SizedBox(width: 16),
                  Expanded(child: _field(_supportPhoneCtrl, 'Téléphone de support')),
                  const SizedBox(width: 16),
                  Expanded(child: _field(_supportWhatsappCtrl, 'Lien WhatsApp de support')),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Textes Légaux (liens vers documents publiés)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_termsUrlCtrl, 'CGU (URL)')),
                  const SizedBox(width: 16),
                  Expanded(child: _field(_privacyUrlCtrl, 'Politique de confidentialité (URL)')),
                  const SizedBox(width: 16),
                  Expanded(child: _field(_legalUrlCtrl, 'Mentions légales (URL)')),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Langues Activées (préparation internationalisation)'),
              const SizedBox(height: 4),
              Text(
                'Marque les langues destinées à être supportées — la traduction effective de '
                'l\'interface est un chantier séparé, pas encore réalisé.',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableLanguages.entries.map((e) {
                  final isFrench = e.key == 'fr';
                  final isSelected = _enabledLanguages.contains(e.key);
                  return FilterChip(
                    label: Text(e.value),
                    selected: isSelected,
                    // Le français est déjà 100% implémenté partout — jamais désactivable.
                    onSelected: isFrench
                        ? null
                        : (sel) => setState(() {
                              if (sel) {
                                _enabledLanguages.add(e.key);
                              } else {
                                _enabledLanguages.remove(e.key);
                              }
                            }),
                    selectedColor: AppTheme.accentBlue.withValues(alpha: 0.25),
                    backgroundColor: AppTheme.primaryDark,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.accentBlue : AppTheme.textMuted,
                    ),
                    disabledColor: AppTheme.accentBlue.withValues(alpha: 0.25),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Disponibilité de l\'Application Élève'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_minVersionCtrl, 'Version minimale requise (ex: 1.2.0)')),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _maintenanceMode
                      ? AppTheme.accentRose.withValues(alpha: 0.1)
                      : AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _maintenanceMode ? AppTheme.accentRose : AppTheme.primaryBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _maintenanceMode ? Icons.warning_rounded : Icons.check_circle_outline_rounded,
                          color: _maintenanceMode ? AppTheme.accentRose : AppTheme.accentEmerald,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mode Maintenance',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        Switch(
                          value: _maintenanceMode,
                          activeThumbColor: AppTheme.accentRose,
                          onChanged: (v) {
                            if (v) {
                              _confirmEnableMaintenance();
                            } else {
                              setState(() => _maintenanceMode = false);
                            }
                          },
                        ),
                      ],
                    ),
                    Text(
                      _maintenanceMode
                          ? 'Rend l\'application élève indisponible pour TOUS les utilisateurs dès l\'enregistrement.'
                          : 'Application élève disponible normalement.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _maintenanceMode ? AppTheme.accentRose : AppTheme.textMuted),
                    ),
                    if (_maintenanceMode) ...[
                      const SizedBox(height: 10),
                      _field(_maintenanceMessageCtrl, 'Message affiché aux élèves', maxLines: 2),
                    ],
                  ],
                ),
              ),

              if (_saveError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_saveError!, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                ),
              ],

              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer les Modifications'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Erreur: $err', style: GoogleFonts.inter(color: AppTheme.accentRose)),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(labelText: label),
    );
  }

  void _confirmEnableMaintenance() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppDialogTitle(
          icon: Icons.warning_rounded,
          iconColor: AppTheme.accentRose,
          text: 'Activer le mode maintenance ?',
          onClose: () => Navigator.pop(ctx),
        ),
        content: Text(
          'Cela rendra l\'application élève indisponible pour TOUS les élèves et parents dès '
          'l\'enregistrement — pas seulement une préparation, un impact réel et immédiat sur les '
          'utilisateurs en cours de session.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _maintenanceMode = true);
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final adminId = ref.read(authProvider).valueOrNull?.id;
    if (adminId == null || _loadedFrom == null) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.updateAppSettings(
        _loadedFrom!.id,
        appName: _appNameCtrl.text.trim().isEmpty ? 'E-Learning' : _appNameCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        supportEmail: _supportEmailCtrl.text.trim(),
        supportPhone: _supportPhoneCtrl.text.trim(),
        supportWhatsappLink: _supportWhatsappCtrl.text.trim(),
        termsUrl: _termsUrlCtrl.text.trim(),
        privacyPolicyUrl: _privacyUrlCtrl.text.trim(),
        legalNoticeUrl: _legalUrlCtrl.text.trim(),
        maintenanceMode: _maintenanceMode,
        maintenanceMessage: _maintenanceMessageCtrl.text.trim(),
        minSupportedAppVersion: _minVersionCtrl.text.trim(),
        enabledLanguages: _enabledLanguages.toList(),
        updatedBy: adminId,
      );
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentEmerald,
            content: Text('Paramètres enregistrés.'),
          ),
        );
      }
    } catch (e) {
      setState(() => _saveError = '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
