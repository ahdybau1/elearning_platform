import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/local_chat_storage_service.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';

/// Composant d'affichage d'une pièce jointe (Image, PDF, Audio)
/// Utilisé dans le dock avant envoi (avec bouton de suppression) et dans les bulles de messages
class ChatAttachmentPill extends StatelessWidget {
  final ChatAttachment attachment;
  final VoidCallback? onRemove;
  final bool isCompact;

  const ChatAttachmentPill({
    super.key,
    required this.attachment,
    this.onRemove,
    this.isCompact = false,
  });

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showFullscreenImage(BuildContext context) {
    if (attachment.type != ChatAttachmentType.image ||
        attachment.base64Data.isEmpty) {
      return;
    }

    try {
      final imageBytes = base64Decode(attachment.base64Data);
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Impossible d\'afficher l\'image en plein écran: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final IconData iconData;
    final Color accentColor;
    final String typeLabel;

    switch (attachment.type) {
      case ChatAttachmentType.image:
        iconData = Icons.image_rounded;
        accentColor = AppColors.cyanAccent;
        typeLabel = 'Image';
        break;
      case ChatAttachmentType.pdf:
        iconData = Icons.picture_as_pdf_rounded;
        accentColor = Colors.redAccent;
        typeLabel = 'PDF';
        break;
      case ChatAttachmentType.audio:
        iconData = Icons.mic_rounded;
        accentColor = AppColors.emeraldSuccess;
        typeLabel = 'Audio';
        break;
      case ChatAttachmentType.file:
        iconData = Icons.insert_drive_file_rounded;
        accentColor = Colors.amber;
        typeLabel = 'Fichier';
        break;
    }

    Widget previewContent;
    if (attachment.type == ChatAttachmentType.image &&
        attachment.base64Data.isNotEmpty) {
      try {
        final imageBytes = base64Decode(attachment.base64Data);
        previewContent = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            imageBytes,
            width: isCompact ? 32 : 44,
            height: isCompact ? 32 : 44,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              iconData,
              color: accentColor,
              size: isCompact ? 20 : 24,
            ),
          ),
        );
      } catch (_) {
        previewContent = Icon(iconData, color: accentColor, size: isCompact ? 20 : 24);
      }
    } else {
      previewContent = Container(
        width: isCompact ? 32 : 40,
        height: isCompact ? 32 : 40,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(iconData, color: accentColor, size: isCompact ? 18 : 22),
      );
    }

    return InkWell(
      onTap: attachment.type == ChatAttachmentType.image
          ? () => _showFullscreenImage(context)
          : null,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      child: Container(
        constraints: BoxConstraints(maxWidth: isCompact ? 220 : 260),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            previewContent,
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                      if (attachment.sizeBytes > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          _formatFileSize(attachment.sizeBytes),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
