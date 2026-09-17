import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Type de pièce jointe supporté dans les messages
enum ChatAttachmentType {
  image,
  pdf,
  audio,
  file;

  static ChatAttachmentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'image':
        return ChatAttachmentType.image;
      case 'pdf':
        return ChatAttachmentType.pdf;
      case 'audio':
        return ChatAttachmentType.audio;
      default:
        return ChatAttachmentType.file;
    }
  }
}

/// Modèle d'une pièce jointe (Photo, Document PDF, Fichier audio/voix)
class ChatAttachment {
  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final ChatAttachmentType type;
  final String base64Data;

  const ChatAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.type,
    required this.base64Data,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'type': type.name,
        'base64Data': base64Data,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Fichier',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      type: ChatAttachmentType.fromString(json['type'] as String? ?? 'file'),
      base64Data: json['base64Data'] as String? ?? '',
    );
  }
}

/// Message individuel dans une conversation
class ChatMessage {
  final String id;
  final String sender; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;
  final List<ChatAttachment> attachments;
  final List<Map<String, dynamic>> citations;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.attachments = const [],
    this.citations = const [],
  });

  bool get isAi => sender == 'ai';
  bool get hasAttachments => attachments.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'citations': citations,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? UniqueKey().toString(),
      sender: json['sender'] as String? ?? 'user',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
      citations: (json['citations'] as List<dynamic>?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          const [],
    );
  }
}

/// Session de conversation stockée localement
class ChatSession {
  final String id;
  final String title;
  final String profileId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.title,
    required this.profileId,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  ChatSession copyWith({
    String? id,
    String? title,
    String? profileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      profileId: profileId ?? this.profileId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'profileId': profileId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? 'Nouvelle discussion',
      profileId: json['profileId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Service de gestion du stockage local et synchronisation multi-appareils
class LocalChatStorageService {
  static const int maxSessions = 10;
  static const String _storagePrefix = 'edlearn_local_chat_sessions_';

  String _getKey(String profileId) => '$_storagePrefix$profileId';

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Récupère toutes les conversations d'un profil :
  /// 1. Retourne d'abord le cache local pour un affichage instantané (0ms)
  /// 2. Récupère en tâche de fond ou parallèle les sessions de Supabase (pour retrouver ses discussions sur un autre appareil)
  Future<List<ChatSession>> getSessions(String profileId) async {
    List<ChatSession> localSessions = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_getKey(profileId));
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        localSessions = decoded
            .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Erreur lors de la lecture des sessions locales: $e');
    }

    // Synchronisation avec la base de données Supabase (multi-appareils)
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final response = await client
            .from('student_chat_sessions')
            .select()
            .eq('profile_id', profileId)
            .order('updated_at', ascending: false)
            .limit(maxSessions);

        if (response.isNotEmpty) {
          final remoteSessions = response.map((row) {
            final rawMessages = row['messages'];
            final List<ChatMessage> messages = (rawMessages is List)
                ? rawMessages
                    .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                    .toList()
                : [];

            return ChatSession(
              id: row['id'] as String,
              title: row['title'] as String? ?? 'Discussion',
              profileId: row['profile_id'] as String,
              createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
              updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
                  DateTime.now(),
              messages: messages,
            );
          }).toList();

          // Fusion des sessions distantes et locales (la plus récente l'emporte par id)
          final Map<String, ChatSession> sessionMap = {
            for (final s in localSessions) s.id: s,
          };

          for (final rem in remoteSessions) {
            final existing = sessionMap[rem.id];
            if (existing == null || rem.updatedAt.isAfter(existing.updatedAt)) {
              sessionMap[rem.id] = rem;
            }
          }

          final mergedList = sessionMap.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          // Si plus de 10, ne garder que les 10 plus récentes
          final cappedList = mergedList.take(maxSessions).toList();

          // Mise à jour du cache local
          final prefs = await SharedPreferences.getInstance();
          final raw = jsonEncode(cappedList.map((s) => s.toJson()).toList());
          await prefs.setString(_getKey(profileId), raw);

          return cappedList;
        }
      } catch (cloudErr) {
        // En cas de coupure réseau temporaire, l'élève continue sur son cache local
        debugPrint('Synchronisation cloud des sessions ignorée: $cloudErr');
      }
    }

    localSessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return localSessions;
  }

  /// Récupère une session précise
  Future<ChatSession?> getSession(String profileId, String sessionId) async {
    final sessions = await getSessions(profileId);
    try {
      return sessions.firstWhere((s) => s.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  /// Vérifie si l'élève peut créer une nouvelle conversation sans dépasser la limite de 10
  Future<bool> canCreateNewSession(String profileId) async {
    final sessions = await getSessions(profileId);
    return sessions.length < maxSessions;
  }

  /// Retourne le nombre de conversations restantes avant d'atteindre la limite
  Future<int> getRemainingQuota(String profileId) async {
    final sessions = await getSessions(profileId);
    final remaining = maxSessions - sessions.length;
    return remaining > 0 ? remaining : 0;
  }

  /// Enregistre ou met à jour une session (local + cloud distant)
  Future<ChatSession> saveSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions(session.profileId);

    final index = sessions.indexWhere((s) => s.id == session.id);
    final updatedSession = session.copyWith(updatedAt: DateTime.now());

    if (index >= 0) {
      sessions[index] = updatedSession;
    } else {
      // Nouvelle session
      sessions.insert(0, updatedSession);
    }

    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_getKey(session.profileId), raw);

    // Synchronisation asynchrone avec Supabase
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final sanitizedMessages = updatedSession.messages.map((m) {
          return {
            'id': m.id,
            'sender': m.sender,
            'text': m.text,
            'timestamp': m.timestamp.toIso8601String(),
            'citations': m.citations,
            'attachments': m.attachments.map((a) {
              return {
                'id': a.id,
                'name': a.name,
                'mimeType': a.mimeType,
                'sizeBytes': a.sizeBytes,
                'type': a.type.name,
                'base64Data': '', // Métadonnées légères en base sans surcharger la BDD
              };
            }).toList(),
          };
        }).toList();

        await client.from('student_chat_sessions').upsert({
          'id': updatedSession.id,
          'profile_id': updatedSession.profileId,
          'title': updatedSession.title,
          'messages': sanitizedMessages,
          'updated_at': updatedSession.updatedAt.toIso8601String(),
        });
      } catch (cloudErr) {
        debugPrint('Erreur synchro cloud saveSession: $cloudErr');
      }
    }

    return updatedSession;
  }

  /// Supprime une session précise (local + cloud distant)
  Future<bool> deleteSession(String profileId, String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions(profileId);

    final beforeCount = sessions.length;
    sessions.removeWhere((s) => s.id == sessionId);

    if (sessions.length != beforeCount) {
      final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_getKey(profileId), raw);

      final client = _supabase;
      if (client != null && client.auth.currentSession != null) {
        try {
          await client
              .from('student_chat_sessions')
              .delete()
              .eq('id', sessionId);
        } catch (cloudErr) {
          debugPrint('Erreur synchro cloud deleteSession: $cloudErr');
        }
      }
      return true;
    }
    return false;
  }

  /// Renomme une session (local + cloud distant)
  Future<bool> renameSession(
    String profileId,
    String sessionId,
    String newTitle,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions(profileId);

    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      final updated = sessions[index].copyWith(
        title: newTitle.trim().isEmpty ? 'Discussion' : newTitle.trim(),
        updatedAt: DateTime.now(),
      );
      sessions[index] = updated;

      final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_getKey(profileId), raw);

      final client = _supabase;
      if (client != null && client.auth.currentSession != null) {
        try {
          await client
              .from('student_chat_sessions')
              .update({
                'title': updated.title,
                'updated_at': updated.updatedAt.toIso8601String(),
              })
              .eq('id', sessionId);
        } catch (cloudErr) {
          debugPrint('Erreur synchro cloud renameSession: $cloudErr');
        }
      }
      return true;
    }
    return false;
  }

  /// Supprime toutes les sessions du profil (local + cloud distant)
  Future<void> clearAllSessions(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey(profileId));

    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        await client
            .from('student_chat_sessions')
            .delete()
            .eq('profile_id', profileId);
      } catch (cloudErr) {
        debugPrint('Erreur synchro cloud clearAllSessions: $cloudErr');
      }
    }
  }
}

/// Provider Riverpod pour le service de stockage local du chat
final localChatStorageServiceProvider = Provider<LocalChatStorageService>((ref) {
  return LocalChatStorageService();
});
