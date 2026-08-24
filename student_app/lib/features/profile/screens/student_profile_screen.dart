import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// Données réelles (compte + profils déjà chargés par studentAuthProvider) — rien à simuler ici,
/// contrairement aux autres pages ajoutées dans cette même passe qui restent volontairement
/// factices en attendant leur propre passe de rigueur.
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(String accountId) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final client = Supabase.instance.client;
      const path = 'avatar.jpg';
      final storagePath = '$accountId/$path';
      await client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      // Paramètre de cache-busting : sans lui, le navigateur garde l'ancienne image en cache pour
      // cette même URL après un remplacement, et le changement de photo semble ne rien faire.
      final publicUrl =
          '${client.storage.from('avatars').getPublicUrl(storagePath)}?v=${DateTime.now().millisecondsSinceEpoch}';
      final error = await ref
          .read(studentAuthProvider.notifier)
          .updatePhotoUrl(publicUrl);
      if (mounted && error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $error')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'envoi de la photo : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(studentAuthProvider);
    final account = authState.account;
    final activeProfile = authState.activeProfile;

    return StudentPageContent(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StudentScreenHeader(title: 'Mon Profil'),
            const SizedBox(height: 20),
            // Identity card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: account == null || _isUploadingPhoto
                        ? null
                        : () => _pickAndUploadPhoto(account.id),
                    child: Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: StudentTheme.primaryGradient,
                          ),
                          child: _isUploadingPhoto
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : (account?.photoUrl?.isNotEmpty == true)
                              ? Image.network(
                                  account!.photoUrl!,
                                  fit: BoxFit.cover,
                                  width: 68,
                                  height: 68,
                                )
                              : Center(
                                  child: Text(
                                    (account?.firstName.isNotEmpty == true)
                                        ? account!.firstName[0].toUpperCase()
                                        : 'É',
                                    style: GoogleFonts.outfit(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: context.colors.accentPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.card,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 12,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${account?.firstName ?? ''} ${account?.lastName ?? ''}'
                              .trim(),
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account?.email ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        if (account?.phone?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            account!.phone!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                        if (account?.schoolName?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            '🏫 ${account!.schoolName}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                        if (account?.birthDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '🎂 ${account!.birthDate!.day.toString().padLeft(2, '0')}/${account.birthDate!.month.toString().padLeft(2, '0')}/${account.birthDate!.year}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modifier mes informations',
                    icon: Icon(
                      Icons.edit_outlined,
                      color: context.colors.textMuted,
                    ),
                    onPressed: account == null ? null : () => _showEditProfileDialog(account),
                  ),
                ],
              ),
            ),

            if (activeProfile != null) ...[
              const SizedBox(height: 20),
              _buildParentInviteCard(activeProfile.id),
            ],

            const SizedBox(height: 28),
            Text(
              'Mes Classes Suivies',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Modèle 1 profil = 1 classe = 1 abonnement (§2.3 du cahier des charges).',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            ...authState.profiles.map(
              (p) => _buildProfileTile(
                p,
                isActive: p.id == activeProfile?.id,
                canArchive: authState.profiles.length > 1,
              ),
            ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/onboarding'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter une classe'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.accentPrimary,
                side: BorderSide(color: context.colors.accentPrimary),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (account != null) ...[
              const SizedBox(height: 28),
              _buildArchivedProfilesSection(account.id),
            ],

            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.card.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.military_tech_outlined,
                    color: context.colors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Badges, séries de régularité & points',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Gamification (§14 du cahier des charges) — bientôt disponible.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// §17 du cahier des charges : le parent crée son propre compte (auto-inscription, voir
  /// student_login_screen.dart) et prouve son lien à cet enfant avec ce code plutôt qu'en partageant
  /// un mot de passe ou en attendant une validation admin — voir migration 44.
  Widget _buildParentInviteCard(String profileId) {
    final codeAsync = ref.watch(parentLinkCodeProvider(profileId));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.family_restroom_rounded, color: context.colors.accentAmber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inviter un parent',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Donnez ce code à votre parent — il l\'utilisera en s\'inscrivant à son propre compte pour suivre votre scolarité (valable 24h).',
                  style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          codeAsync.when(
            loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, _) => Icon(Icons.error_outline_rounded, color: context.colors.accentRose),
            data: (code) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                code,
                style: GoogleFonts.firaCode(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2, color: context.colors.accentAmber),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(StudentAccount account) async {
    final firstNameCtrl = TextEditingController(text: account.firstName);
    final lastNameCtrl = TextEditingController(text: account.lastName);
    final schoolCtrl = TextEditingController(text: account.schoolName ?? '');
    DateTime? birthDate = account.birthDate;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(
            'Modifier mes informations',
            style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Prénom',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: schoolCtrl,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Établissement (optionnel)',
                    labelStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: birthDate ?? DateTime(2010, 1, 1),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => birthDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date de naissance (optionnel)',
                      labelStyle: TextStyle(color: context.colors.textSecondary),
                      filled: true,
                      fillColor: context.colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      birthDate != null
                          ? '${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}'
                          : 'Non renseignée',
                      style: TextStyle(color: context.colors.textPrimary),
                    ),
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
                      if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      final error = await ref.read(studentAuthProvider.notifier).updateProfileInfo(
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            schoolName: schoolCtrl.text,
                            birthDate: birthDate,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted && error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $error')));
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Enregistrer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArchive(StudentProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Archiver ce profil ?',
          style: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '${p.name} (${p.className}) sera masqué mais pourra être réactivé à tout moment. Aucune donnée n\'est supprimée (§2.5 du cahier des charges).',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Archiver',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await ref
        .read(studentAuthProvider.notifier)
        .archiveProfile(p.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $error')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil archivé.')));
    }
  }

  Future<void> _reactivate(StudentProfile p) async {
    final error = await ref
        .read(studentAuthProvider.notifier)
        .reactivateProfile(p.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $error')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil réactivé.')));
      ref.invalidate(archivedProfilesProvider);
    }
  }

  Widget _buildArchivedProfilesSection(String accountId) {
    final archivedAsync = ref.watch(archivedProfilesProvider(accountId));

    return archivedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => const SizedBox.shrink(),
      data: (archived) {
        if (archived.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profils archivés',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Masqués mais conservés — réactivables à tout moment (§2.5 du cahier des charges).',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ...archived.map(
              (p) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.colors.card.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.className,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          Text(
                            'Année ${p.schoolYear}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _reactivate(p),
                      icon: Icon(
                        Icons.restore_rounded,
                        size: 16,
                        color: context.colors.accentPrimary,
                      ),
                      label: Text(
                        'Réactiver',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.colors.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileTile(
    StudentProfile p, {
    required bool isActive,
    required bool canArchive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? context.colors.accentPrimary.withValues(alpha: 0.6)
              : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: context.colors.accentIndigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.school_outlined,
              color: context.colors.accentIndigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.className,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.accentPrimary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Actif',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: context.colors.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Année ${p.schoolYear}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.hasActiveSubscription
                  ? context.colors.accentEmerald.withValues(alpha: 0.15)
                  : context.colors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.hasActiveSubscription
                  ? 'Pass ${p.subscriptionTier.toUpperCase()}'
                  : 'Gratuit',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: p.hasActiveSubscription
                    ? context.colors.accentEmerald
                    : context.colors.textSecondary,
              ),
            ),
          ),
          if (canArchive) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Archiver ce profil',
              icon: Icon(
                Icons.archive_outlined,
                size: 18,
                color: context.colors.textMuted,
              ),
              onPressed: () => _confirmArchive(p),
            ),
          ],
        ],
      ),
    );
  }
}
