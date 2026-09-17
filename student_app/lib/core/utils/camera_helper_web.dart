// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/local_chat_storage_service.dart';
import '../../design_system/tokens/app_colors.dart';

/// Implémentation Web avec accès caméra direct (HTML5 WebRTC getUserMedia)
Future<ChatAttachment?> captureCameraPhoto(BuildContext context) async {
  // Vérifie si l'API mediaDevices est disponible
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    return _fallbackPickImage();
  }

  try {
    final attachment = await showDialog<ChatAttachment>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const _WebcamCaptureDialog(),
    );
    return attachment;
  } catch (e) {
    debugPrint('Erreur modale caméra web: $e');
    return _fallbackPickImage();
  }
}

Future<ChatAttachment?> _fallbackPickImage() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return ChatAttachment(
      id: UniqueKey().toString(),
      name: picked.name.isNotEmpty
          ? picked.name
          : 'Photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      mimeType: picked.mimeType ?? 'image/jpeg',
      sizeBytes: bytes.length,
      type: ChatAttachmentType.image,
      base64Data: base64Encode(bytes),
    );
  } catch (_) {
    return null;
  }
}

class _WebcamCaptureDialog extends StatefulWidget {
  const _WebcamCaptureDialog();

  @override
  State<_WebcamCaptureDialog> createState() => _WebcamCaptureDialogState();
}

class _WebcamCaptureDialogState extends State<_WebcamCaptureDialog> {
  html.MediaStream? _stream;
  late html.VideoElement _videoElement;
  late String _viewId;
  bool _isReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewId = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '16px';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => _videoElement,
    );

    _initWebcam();
  }

  Future<void> _initWebcam() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });

      if (stream != null && mounted) {
        _stream = stream;
        _videoElement.srcObject = stream;
        await _videoElement.play();
        setState(() {
          _isReady = true;
        });
      } else {
        setState(() {
          _errorMessage = 'Caméra indisponible ou autorisation refusée.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible d\'activer la caméra : $e';
        });
      }
    }
  }

  void _snapPhoto() {
    if (_stream == null) return;

    try {
      final width = _videoElement.videoWidth > 0 ? _videoElement.videoWidth : 800;
      final height = _videoElement.videoHeight > 0 ? _videoElement.videoHeight : 600;

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(_videoElement, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      final base64Pure = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;

      _cleanup();

      final attachment = ChatAttachment(
        id: UniqueKey().toString(),
        name: 'Photo_Camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: (base64Pure.length * 0.75).round(),
        type: ChatAttachmentType.image,
        base64Data: base64Pure,
      );

      Navigator.of(context).pop(attachment);
    } catch (e) {
      debugPrint('Erreur lors de la capture de la photo: $e');
      _cleanup();
      Navigator.of(context).pop();
    }
  }

  void _cleanup() {
    _stream?.getTracks().forEach((track) {
      track.stop();
    });
    _stream = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.cyanAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Prendre une photo (Caméra)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _cleanup();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Viseur vidéo de la caméra
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam_off_rounded,
                                      size: 40, color: Colors.redAccent),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : !_isReady
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.cyanAccent,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Activation de la caméra en cours...',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              )
                            : HtmlElementView(viewType: _viewId),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Barre d'action avec bouton déclencheur
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      _cleanup();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _isReady ? _snapPhoto : null,
                    borderRadius: BorderRadius.circular(36),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: _isReady
                            ? AppColors.primaryGradient
                            : const LinearGradient(
                                colors: [Colors.grey, Colors.blueGrey],
                              ),
                        shape: BoxShape.circle,
                        boxShadow: _isReady
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryCyan
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Équilibre visuel
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
