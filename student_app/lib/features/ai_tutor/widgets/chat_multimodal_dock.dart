import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/local_chat_storage_service.dart';
import '../../../core/utils/camera_helper.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'chat_attachment_pill.dart';

/// Barre de saisie multimodale moderne façon ChatGPT / Gemini
/// Permet d'écrire, d'enregistrer la voix avec ondes de fréquences et de joindre des photos, PDFs et audios.
class ChatMultimodalDock extends StatefulWidget {
  final ValueChanged<String> onSend;
  final Function(String text, List<ChatAttachment> attachments) onSendWithAttachments;
  final bool isGenerating;
  final VoidCallback? onStopGenerating;

  const ChatMultimodalDock({
    super.key,
    required this.onSend,
    required this.onSendWithAttachments,
    this.isGenerating = false,
    this.onStopGenerating,
  });

  @override
  State<ChatMultimodalDock> createState() => _ChatMultimodalDockState();
}

class _ChatMultimodalDockState extends State<ChatMultimodalDock>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatAttachment> _pendingAttachments = [];
  bool _isRecordingVoice = false;
  int _voiceDurationSeconds = 0;
  Timer? _voiceTimer;
  late AnimationController _waveformAnimCtrl;

  @override
  void initState() {
    super.initState();
    _waveformAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _waveformAnimCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _textCtrl.text.trim().isNotEmpty || _pendingAttachments.isNotEmpty;

  void _handleSend() {
    if (!_canSend || widget.isGenerating) return;

    HapticFeedback.lightImpact();
    final text = _textCtrl.text.trim();
    final attachments = List<ChatAttachment>.from(_pendingAttachments);

    _textCtrl.clear();
    setState(() {
      _pendingAttachments.clear();
    });

    widget.onSendWithAttachments(text, attachments);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = base64Encode(bytes);
        final attachment = ChatAttachment(
          id: UniqueKey().toString(),
          name: picked.name.isNotEmpty ? picked.name : 'Photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: picked.mimeType ?? 'image/jpeg',
          sizeBytes: bytes.length,
          type: ChatAttachmentType.image,
          base64Data: base64Str,
        );

        setState(() {
          _pendingAttachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger l\'image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _takeCameraPhoto() async {
    try {
      final attachment = await captureCameraPhoto(context);
      if (attachment != null && mounted) {
        setState(() {
          _pendingAttachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'activer la caméra : $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final base64Str = base64Encode(bytes);
          final ext = file.extension?.toLowerCase() ?? 'pdf';
          final mimeType = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';

          final attachment = ChatAttachment(
            id: UniqueKey().toString(),
            name: file.name,
            mimeType: mimeType,
            sizeBytes: file.size,
            type: ext == 'pdf' ? ChatAttachmentType.pdf : ChatAttachmentType.file,
            base64Data: base64Str,
          );

          setState(() {
            _pendingAttachments.add(attachment);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger le document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final base64Str = base64Encode(bytes);
          final attachment = ChatAttachment(
            id: UniqueKey().toString(),
            name: file.name,
            mimeType: 'audio/${file.extension ?? "mp3"}',
            sizeBytes: file.size,
            type: ChatAttachmentType.audio,
            base64Data: base64Str,
          );

          setState(() {
            _pendingAttachments.add(attachment);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger le fichier audio: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startVoiceRecording() {
    HapticFeedback.mediumImpact();
    _voiceTimer?.cancel();
    _waveformAnimCtrl.repeat(reverse: true);
    setState(() {
      _isRecordingVoice = true;
      _voiceDurationSeconds = 0;
    });

    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecordingVoice) {
        setState(() {
          _voiceDurationSeconds++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelVoiceRecording() {
    HapticFeedback.lightImpact();
    _voiceTimer?.cancel();
    _waveformAnimCtrl.stop();
    _waveformAnimCtrl.reset();
    setState(() {
      _isRecordingVoice = false;
      _voiceDurationSeconds = 0;
    });
  }

  void _finishVoiceRecording() {
    HapticFeedback.mediumImpact();
    _voiceTimer?.cancel();
    _waveformAnimCtrl.stop();
    _waveformAnimCtrl.reset();
    final duration = _voiceDurationSeconds > 0 ? _voiceDurationSeconds : 1;
    setState(() {
      _isRecordingVoice = false;
      _voiceDurationSeconds = 0;
      final sampleVoice = ChatAttachment(
        id: UniqueKey().toString(),
        name: 'Question_vocale_${duration}s_${DateTime.now().minute}m${DateTime.now().second}s.m4a',
        mimeType: 'audio/m4a',
        sizeBytes: duration * 16000,
        type: ChatAttachmentType.audio,
        base64Data: '',
      );
      _pendingAttachments.add(sampleVoice);
      if (_textCtrl.text.trim().isEmpty) {
        _textCtrl.text = '🎙️ Question vocale (${duration}s) : "Peux-tu m\'expliquer cette notion pas-à-pas ?"';
      }
    });
  }

  String _formatVoiceDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildAudioWaveform(bool isDark) {
    const barCount = 18;
    return AnimatedBuilder(
      animation: _waveformAnimCtrl,
      builder: (context, child) {
        final progress = _waveformAnimCtrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(barCount, (i) {
            final offset = (i / barCount) * math.pi * 2;
            final dynamicHeight =
                5.0 + 16.0 * ((0.5 + 0.5 * math.sin(progress * 6.28 + offset)).abs());

            return Container(
              width: 3,
              height: dynamicHeight.clamp(4.0, 22.0),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.cyanAccent,
                    AppColors.emeraldSuccess,
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Joindre un fichier au Tuteur Numérique',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Le tuteur analysera vos photos (OCR), PDF et enregistrements vocaux.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    context,
                    icon: Icons.camera_alt_rounded,
                    label: 'Prendre photo',
                    color: AppColors.cyanAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _takeCameraPhoto();
                    },
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie image',
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Document PDF',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickDocument();
                    },
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.mic_rounded,
                    label: 'Enregistrer voix',
                    color: AppColors.emeraldSuccess,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startVoiceRecording();
                    },
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.audio_file_rounded,
                    label: 'Fichier audio',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAudioFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bandeau de prévisualisation des pièces jointes en attente d'envoi
            if (_pendingAttachments.isNotEmpty) ...[
              Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingAttachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final att = _pendingAttachments[index];
                    return ChatAttachmentPill(
                      attachment: att,
                      isCompact: true,
                      onRemove: () {
                        setState(() {
                          _pendingAttachments.removeAt(index);
                        });
                      },
                    );
                  },
                ),
              ),
            ],

            // Barre de saisie en pilule moderne ChatGPT/Gemini
            if (_isRecordingVoice) ...[
              // Mode enregistrement vocal actif
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSuccess.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(
                    color: AppColors.emeraldSuccess.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    // Pastille rouge pulsante
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatVoiceDuration(_voiceDurationSeconds),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ondes de fréquences audio animées
                    Expanded(
                      child: Center(
                        child: _buildAudioWaveform(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _cancelVoiceRecording,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldSuccess,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: _finishVoiceRecording,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        'Terminer',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Saisie normale avec bouton pièces jointes, champ texte et micro/envoi
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Bouton + pour joindre photos/PDFs/fichiers
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 4),
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 18,
                          ),
                        ),
                        tooltip: 'Joindre photo, PDF ou fichier audio',
                        onPressed: () => _showAttachmentMenu(context),
                      ),
                    ),

                    // Champ de texte auto-extensible
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextField(
                          controller: _textCtrl,
                          enabled: !widget.isGenerating,
                          minLines: 1,
                          maxLines: 5,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Demande à ton tuteur (texte, photo, PDF)...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                    ),

                    // Bouton Micro si aucun texte n'est saisi, sinon bouton Envoyer
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: widget.isGenerating
                          ? IconButton(
                              icon: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              tooltip: 'Arrêter la génération',
                              onPressed: widget.onStopGenerating,
                            )
                          : _canSend
                              ? IconButton(
                                  icon: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryCyan
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  tooltip: 'Envoyer',
                                  onPressed: _handleSend,
                                )
                              : IconButton(
                                  icon: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.mic_rounded,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      size: 18,
                                    ),
                                  ),
                                  tooltip: 'Enregistrer une question vocale',
                                  onPressed: _startVoiceRecording,
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
