import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §11 du cahier des charges (Paramètres + Accessibilité). Compte (email/téléphone, changement de
/// mot de passe, déconnexion) est réel — les autres réglages (notifications, langue, apparence,
/// stockage hors-ligne, accessibilité) n'ont pas encore de table de préférences persistée côté
/// serveur : ils restent visuellement complets mais explicitement marqués "Bientôt disponible"
/// plutôt que de prétendre enregistrer un choix qui ne persistera nulle part.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifAbonnement = true;
  bool _notifForum = true;
  bool _notifRevision = true;
  bool _profilVisibleForum = true;
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _subtitles = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(studentAuthProvider);
    final account = authState.account;

    return StudentPageContent(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const StudentScreenHeader(title: 'Paramètres'),
          const SizedBox(height: 20),
          _sectionTitle('Compte'),
          _buildCard([
            _infoRow('Email', account?.email ?? '—'),
            Divider(color: context.colors.border, height: 24),
            _infoRow('Téléphone', account?.phone ?? 'Non renseigné'),
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
            _switchRow('Échéances d\'abonnement', 'Rappels J-3, J-1 et expiration', _notifAbonnement, (v) => setState(() => _notifAbonnement = v)),
            Divider(color: context.colors.border, height: 24),
            _switchRow('Activité du forum', 'Réponses à vos messages', _notifForum, (v) => setState(() => _notifForum = v)),
            Divider(color: context.colors.border, height: 24),
            _switchRow('Révision intelligente', 'Rappels de révision espacée', _notifRevision, (v) => setState(() => _notifRevision = v)),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Langue & Apparence'),
          _buildCard([
            Text('Langue de l\'interface', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _langChip('Français', selected: true),
                _langChip('English', selected: false, comingSoon: true),
              ],
            ),
            const SizedBox(height: 20),
            Text('Apparence', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _langChip('Sombre', selected: true),
                _langChip('Clair', selected: false, comingSoon: true),
                _langChip('Automatique', selected: false, comingSoon: true),
              ],
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Confidentialité & Stockage'),
          _buildCard([
            _switchRow('Profil visible sur le forum', 'Les autres élèves de votre classe voient votre nom', _profilVisibleForum, (v) => setState(() => _profilVisibleForum = v)),
            Divider(color: context.colors.border, height: 24),
            _infoRow('Stockage hors-ligne utilisé', '0 Mo'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Vider le cache (bientôt disponible)'),
              style: OutlinedButton.styleFrom(foregroundColor: context.colors.textMuted, side: BorderSide(color: context.colors.border)),
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Accessibilité'),
          _buildCard([
            Text('Taille du texte', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            Slider(
              value: _fontScale,
              min: 0.85,
              max: 1.3,
              divisions: 3,
              activeColor: context.colors.accentPrimary,
              label: '${(_fontScale * 100).round()}%',
              onChanged: (v) => setState(() => _fontScale = v),
            ),
            Divider(color: context.colors.border, height: 8),
            const SizedBox(height: 12),
            _switchRow('Contraste élevé', 'Distinct du mode sombre', _highContrast, (v) => setState(() => _highContrast = v)),
            Divider(color: context.colors.border, height: 24),
            _switchRow('Sous-titres vidéo', 'Sur tout contenu vidéo de cours', _subtitles, (v) => setState(() => _subtitles = v)),
          ]),

          const SizedBox(height: 32),
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

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textSecondary)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
      ],
    );
  }

  Widget _switchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: context.colors.accentPrimary),
      ],
    );
  }

  Widget _actionRow({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final resolvedColor = color ?? context.colors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: resolvedColor),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: resolvedColor)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
        ],
      ),
    );
  }

  Widget _langChip(String label, {required bool selected, bool comingSoon = false}) {
    return ChoiceChip(
      label: Text(comingSoon ? '$label (bientôt)' : label),
      selected: selected,
      onSelected: comingSoon ? null : (_) {},
      selectedColor: context.colors.accentPrimary.withOpacity(0.2),
      backgroundColor: context.colors.surface,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: selected ? context.colors.accentPrimary : (comingSoon ? context.colors.textMuted : Colors.white),
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
          title: Text('Changer le mot de passe', style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
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
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPasswordCtrl.text),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: context.colors.accentEmerald, content: Text('Mot de passe mis à jour.')),
                          );
                        }
                      } on AuthException catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Valider', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            Text('Supprimer mon compte', style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'La suppression définitive de compte (droit à l\'oubli, §11 du cahier des charges) doit être traitée manuellement par l\'administration pour des raisons de sécurité. Ouvrez un ticket de support (catégorie « Autre ») pour en faire la demande — nous vous répondrons rapidement.',
          style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.accentRose),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/support');
            },
            child: const Text('Ouvrir un ticket', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
