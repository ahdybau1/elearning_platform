import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';

/// Avatar cliquable de l'écran profil (upload de photo) — extrait de `StudentProfileScreen`
/// (`_pickAndUploadPhoto` + le `Stack` avatar, découpage du fichier monolithique).
class ProfileAvatarUploader extends ConsumerStatefulWidget {
  const ProfileAvatarUploader({super.key, required this.account});

  final StudentAccount? account;

  @override
  ConsumerState<ProfileAvatarUploader> createState() =>
      _ProfileAvatarUploaderState();
}

class _ProfileAvatarUploaderState
    extends ConsumerState<ProfileAvatarUploader> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mise à jour de la photo impossible.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Envoi de la photo impossible.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return Semantics(
      button: true,
      label: 'Modifier la photo de profil',
      child: GestureDetector(
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
                  border: Border.all(color: context.colors.card, width: 2),
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
    );
  }
}
