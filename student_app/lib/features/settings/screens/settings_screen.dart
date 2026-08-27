import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/models/student_models.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §11 du cahier des charges (Paramètres + Accessibilité). Tout ce qui peut réellement persister le
/// fait désormais via `account_settings` (migration 40) — voir studentAuthProvider.updateSettings.
/// Trois points restent honnêtement marqués "à venir" plutôt que simulés : la traduction anglaise
/// (aucune infrastructure i18n dans l'app), le téléchargement hors-ligne (aucun moteur de cache de
/// leçons n'existe encore) et les sous-titres vidéo (aucun lecteur vidéo à qui les appliquer) — voir
/// l'addendum daté dans docs/cahier_des_charges.md pour le détail de ce périmètre.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(studentAuthProvider);
    final account = authState.account;
    final settings = authState.settings ?? const AccountSettings();

    Future<void> update(Map<String, dynamic> partial) async {
      final error = await ref
          .read(studentAuthProvider.notifier)
          .updateSettings(partial);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $error')));
      }
    }

    return StudentPageContent(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const StudentScreenHeader(title: 'Paramètres'),
          const SizedBox(height: 20),
          _sectionTitle('Compte'),
          _buildCard([
            _infoRow('Email', account?.email ?? '—'),
            Divider(color: context.colors.border, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _infoRow(
                    'Téléphone',
                    account?.phone ?? 'Non renseigné',
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: context.colors.textMuted,
                  ),
                  onPressed: () =>
                      _showEditPhoneDialog(context, account?.phone ?? ''),
                ),
              ],
            ),
            Divider(color: context.colors.border, height: 24),
            _actionRow(
              icon: Icons.lock_outline_rounded,
              label: 'Changer le mot de passe',
              onTap: () => _showChangePasswordDialog(context),
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Notifications'),
          _buildCard([
            _switchRow(
              'Échéances d\'abonnement',
              'Rappels J-3, J-1 et expiration',
              settings.notifSubscription,
              (v) => update({'notif_subscription': v}),
            ),
            Divider(color: context.colors.border, height: 24),
            _switchRow(
              'Activité du forum',
              'Réponses à vos messages',
              settings.notifForum,
              (v) => update({'notif_forum': v}),
            ),
            Divider(color: context.colors.border, height: 24),
            _switchRow(
              'Révision intelligente',
              'Rappels de révision espacée',
              settings.notifRevision,
              (v) => update({'notif_revision': v}),
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Langue & Apparence'),
          _buildCard([
            Text(
              'Langue de l\'interface',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _chip('Français', selected: true, onSelected: () {}),
                _chip(
                  'English',
                  selected: false,
                  comingSoon: true,
                  onSelected: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Apparence',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _chip(
                  'Sombre',
                  selected: settings.themeMode == 'dark',
                  onSelected: () => update({'theme_mode': 'dark'}),
                ),
                _chip(
                  'Clair',
                  selected: settings.themeMode == 'light',
                  onSelected: () => update({'theme_mode': 'light'}),
                ),
                _chip(
                  'Automatique',
                  selected: settings.themeMode == 'system',
                  onSelected: () => update({'theme_mode': 'system'}),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Confidentialité & Stockage'),
          _buildCard([
            _switchRow(
              'Profil visible sur le forum',
              'Les autres élèves de votre classe voient votre nom',
              settings.forumProfileVisible,
              (v) => update({'forum_profile_visible': v}),
            ),
            Divider(color: context.colors.border, height: 24),
            Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 18,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aucun contenu téléchargé pour l\'instant — le téléchargement hors-ligne des leçons arrive dans une prochaine mise à jour.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Accessibilité'),
          _buildCard([
            Text(
              'Taille du texte',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            Slider(
              value: settings.fontScale,
              min: 0.85,
              max: 1.3,
              divisions: 3,
              activeColor: context.colors.accentPrimary,
              label: '${(settings.fontScale * 100).round()}%',
              onChanged: (v) => update({'font_scale': v}),
            ),
            Divider(color: context.colors.border, height: 8),
            const SizedBox(height: 12),
            _switchRow(
              'Contraste élevé',
              'Distinct du mode sombre — s\'applique au thème clair et sombre',
              settings.highContrast,
              (v) => update({'high_contrast': v}),
            ),
            Divider(color: context.colors.border, height: 24),
            _switchRow(
              'Sous-titres vidéo',
              'Sur tout contenu vidéo de cours (arrive avec le lecteur vidéo)',
              settings.subtitlesEnabled,
              (v) => update({'subtitles_enabled': v}),
            ),
          ]),

          const SizedBox(height: 32),
          _sectionTitle('Vos données'),
          _buildCard([
            Text(
              'Droit à l\'oubli : demandez une copie de vos données ou leur suppression définitive. Le traitement est effectué manuellement par l\'administration.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitDataRequest(context, 'export'),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Exporter mes données'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textPrimary,
                      side: BorderSide(color: context.colors.border),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Zone sensible'),
          _buildCard([
            _actionRow(
              icon: Icons.logout_rounded,
              label: 'Se déconnecter',
              color: context.colors.textSecondary,
              onTap: () => ref.read(studentAuthProvider.notifier).signOut(),
            ),
            Divider(color: context.colors.border, height: 24),
            _actionRow(
              icon: Icons.delete_forever_outlined,
              label: 'Supprimer mon compte',
              color: context.colors.accentRose,
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _submitDataRequest(
    BuildContext context,
    String requestType,
  ) async {
    final error = await ref
        .read(studentAuthProvider.notifier)
        .createDataRequest(requestType);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error != null
              ? 'Erreur : $error'
              : requestType == 'export'
              ? 'Demande d\'export enregistrée — l\'administration vous contactera.'
              : 'Demande de suppression enregistrée — l\'administration vous contactera.',
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: context.colors.textSecondary,
      ),
    ),
  );

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: context.colors.accentPrimary,
        ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final resolvedColor = color ?? context.colors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: resolvedColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: resolvedColor,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: context.colors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    bool comingSoon = false,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(comingSoon ? '$label (bientôt)' : label),
      selected: selected,
      onSelected: comingSoon ? null : (_) => onSelected(),
      selectedColor: context.colors.accentPrimary.withValues(alpha: 0.2),
      backgroundColor: context.colors.surface,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: selected
            ? context.colors.accentPrimary
            : (comingSoon
                  ? context.colors.textMuted
                  : context.colors.textPrimary),
      ),
    );
  }

  void _showEditPhoneDialog(BuildContext context, String currentPhone) {
    final phoneCtrl = TextEditingController(text: currentPhone);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(
            'Modifier le téléphone',
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              labelStyle: TextStyle(color: context.colors.textSecondary),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final error = await ref
                          .read(studentAuthProvider.notifier)
                          .updatePhone(phoneCtrl.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted && error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $error')),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Valider',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(
            'Changer le mot de passe',
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: newPasswordCtrl,
              obscureText: true,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                labelStyle: TextStyle(color: context.colors.textSecondary),
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPasswordCtrl.text),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: context.colors.accentEmerald,
                              content: Text('Mot de passe mis à jour.'),
                            ),
                          );
                        }
                      } on AuthException catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Valider',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.colors.accentRose),
            const SizedBox(width: 10),
            Text(
              'Supprimer mon compte',
              style: GoogleFonts.outfit(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'La suppression définitive de compte (droit à l\'oubli, §11 du cahier des charges) est traitée manuellement par l\'administration pour des raisons de sécurité. Confirmez pour enregistrer votre demande — nous vous répondrons rapidement.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.accentRose,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitDataRequest(context, 'deletion');
            },
            child: const Text(
              'Confirmer la demande',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
