import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/core/services/local_chat_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalChatStorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = LocalChatStorageService();
  });

  group('LocalChatStorageService Unit Tests', () {
    test('initial sessions list is empty for a new profile', () async {
      final sessions = await storage.getSessions('student_1');
      expect(sessions, isEmpty);
      expect(await storage.canCreateNewSession('student_1'), isTrue);
      expect(await storage.getRemainingQuota('student_1'), equals(10));
    });

    test('saves and retrieves a chat session correctly', () async {
      final session = ChatSession(
        id: 'sess_1',
        title: 'Polynôme du second degré',
        profileId: 'student_1',
        createdAt: DateTime(2026, 9, 17, 10, 0),
        updatedAt: DateTime(2026, 9, 17, 10, 0),
        messages: [
          ChatMessage(
            id: 'm1',
            sender: 'user',
            text: 'Comment calculer le discriminant ?',
            timestamp: DateTime(2026, 9, 17, 10, 1),
            attachments: [
              const ChatAttachment(
                id: 'att_1',
                name: 'cours.pdf',
                mimeType: 'application/pdf',
                sizeBytes: 1024,
                type: ChatAttachmentType.pdf,
                base64Data: 'dummy_base64',
              ),
            ],
          ),
          ChatMessage(
            id: 'm2',
            sender: 'ai',
            text: r'Le discriminant est donné par $\Delta = b^2 - 4ac$.',
            timestamp: DateTime(2026, 9, 17, 10, 2),
          ),
        ],
      );

      final saved = await storage.saveSession(session);
      expect(saved.id, equals('sess_1'));

      final retrieved = await storage.getSession('student_1', 'sess_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Polynôme du second degré'));
      expect(retrieved.messages.length, equals(2));
      expect(retrieved.messages.first.attachments.length, equals(1));
      expect(retrieved.messages.first.attachments.first.name, equals('cours.pdf'));
      expect(retrieved.messages.first.attachments.first.type, equals(ChatAttachmentType.pdf));
    });

    test('profile isolation: sessions of one student are not visible to another', () async {
      final session1 = ChatSession(
        id: 'sess_1',
        title: 'Session Élève 1',
        profileId: 'student_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final session2 = ChatSession(
        id: 'sess_2',
        title: 'Session Élève 2',
        profileId: 'student_2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveSession(session1);
      await storage.saveSession(session2);

      final s1List = await storage.getSessions('student_1');
      final s2List = await storage.getSessions('student_2');

      expect(s1List.length, equals(1));
      expect(s1List.first.id, equals('sess_1'));

      expect(s2List.length, equals(1));
      expect(s2List.first.id, equals('sess_2'));
    });

    test('quota enforcement: max 10 sessions per profile', () async {
      const profileId = 'quota_test_student';

      for (int i = 1; i <= 9; i++) {
        await storage.saveSession(
          ChatSession(
            id: 'sess_$i',
            title: 'Session $i',
            profileId: profileId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        expect(await storage.canCreateNewSession(profileId), isTrue);
      }

      // Add 10th session
      await storage.saveSession(
        ChatSession(
          id: 'sess_10',
          title: 'Session 10',
          profileId: profileId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      expect(await storage.canCreateNewSession(profileId), isFalse);
      expect(await storage.getRemainingQuota(profileId), equals(0));
    });

    test('renames and deletes session properly', () async {
      const profileId = 'edit_student';
      final session = ChatSession(
        id: 's_edit',
        title: 'Titre Original',
        profileId: profileId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveSession(session);

      // Rename
      final renamed = await storage.renameSession(profileId, 's_edit', 'Nouveau Titre');
      expect(renamed, isTrue);

      final updated = await storage.getSession(profileId, 's_edit');
      expect(updated?.title, equals('Nouveau Titre'));

      // Delete
      final deleted = await storage.deleteSession(profileId, 's_edit');
      expect(deleted, isTrue);

      final afterDelete = await storage.getSession(profileId, 's_edit');
      expect(afterDelete, isNull);
    });

    test('clearAllSessions wipes everything for target profile only', () async {
      await storage.saveSession(ChatSession(
        id: 's_wipe_1',
        title: 'T1',
        profileId: 'p_wipe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await storage.saveSession(ChatSession(
        id: 's_wipe_2',
        title: 'T2',
        profileId: 'p_keep',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await storage.clearAllSessions('p_wipe');

      expect(await storage.getSessions('p_wipe'), isEmpty);
      expect((await storage.getSessions('p_keep')).length, equals(1));
    });
  });
}
