import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

/// Sélecteur de médias réel (upload vers Supabase Storage, bucket "media" — voir
/// 08_media_storage.sql) : plus de champ texte où coller une URL à la main. Utilisable dans tout
/// éditeur de contenu (leçon, exercice) pour attacher images/documents/audio/vidéo.
class MediaAttachmentPicker extends ConsumerStatefulWidget {
  final List<MediaAsset> initialAssets;
  final ValueChanged<List<MediaAsset>> onChanged;

  const MediaAttachmentPicker({
    super.key,
    this.initialAssets = const [],
    required this.onChanged,
  });

  @override
  ConsumerState<MediaAttachmentPicker> createState() => _MediaAttachmentPickerState();
}

class _MediaAttachmentPickerState extends ConsumerState<MediaAttachmentPicker> {
  late List<MediaAsset> _assets;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _assets = List.of(widget.initialAssets);
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        setState(() => _isUploading = false);
        return;
      }

      final service = ref.read(supabaseServiceProvider);
      final uploadedBy = ref.read(authProvider).valueOrNull?.id ??
          '00000000-0000-0000-0000-000000000001';
      final asset = await service.uploadMedia(
        bytes: bytes,
        filename: file.name,
        uploadedBy: uploadedBy,
      );

      setState(() {
        _assets = [..._assets, asset];
        _isUploading = false;
      });
      widget.onChanged(_assets);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Échec de l\'upload : $e';
      });
    }
  }

  void _remove(MediaAsset asset) {
    setState(() => _assets = _assets.where((a) => a.id != asset.id).toList());
    widget.onChanged(_assets);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: _isUploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 16),
              label: Text(_isUploading ? 'Envoi en cours...' : 'Ajouter un média'),
            ),
            const SizedBox(width: 10),
            Text(
              'Images, vidéos, audio, documents',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: GoogleFonts.inter(color: AppTheme.accentRose, fontSize: 12)),
          ),
        if (_assets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assets.map((asset) {
                return Chip(
                  avatar: Icon(_iconFor(asset.type), size: 16, color: AppTheme.accentBlue),
                  label: Text(
                    asset.filename,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: AppTheme.primaryDark,
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () => _remove(asset),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
