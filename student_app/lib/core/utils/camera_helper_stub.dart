import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/local_chat_storage_service.dart';

/// Implémentation native (Android / iOS / Desktop natif)
Future<ChatAttachment?> captureCameraPhoto(BuildContext context) async {
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
  } catch (e) {
    debugPrint('Erreur capture native: $e');
    return null;
  }
}
