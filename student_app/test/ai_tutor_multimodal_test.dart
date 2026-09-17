import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/core/auth/student_auth_provider.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/core/services/local_chat_storage_service.dart';
import 'package:student_app/features/ai_tutor/screens/ai_tutor_chat_screen.dart';
import 'package:student_app/features/ai_tutor/widgets/chat_attachment_pill.dart';
import 'package:student_app/features/ai_tutor/widgets/chat_history_drawer.dart';
import 'package:student_app/features/ai_tutor/widgets/chat_multimodal_dock.dart';

class _FakeStudentAuthNotifier extends StudentAuthNotifier {
  _FakeStudentAuthNotifier(this._fixed) {
    state = _fixed;
  }
  final StudentAuthState _fixed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final profile = StudentProfile(
    id: 'profile-1',
    accountId: 'account-1',
    classNodeId: 'class-1',
    className: 'Terminale D',
    schoolYear: '2025-2026',
  );

  group('AI Tutor Multimodal Widgets Tests', () {
    testWidgets('ChatAttachmentPill displays correctly for PDF and Audio',
        (tester) async {
      const pdfAtt = ChatAttachment(
        id: '1',
        name: 'Devoir_Maths.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 154000,
        type: ChatAttachmentType.pdf,
        base64Data: '',
      );

      const audioAtt = ChatAttachment(
        id: '2',
        name: 'Question_vocale.m4a',
        mimeType: 'audio/m4a',
        sizeBytes: 45000,
        type: ChatAttachmentType.audio,
        base64Data: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChatAttachmentPill(attachment: pdfAtt),
                ChatAttachmentPill(attachment: audioAtt),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Devoir_Maths.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Question_vocale.m4a'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('ChatHistoryDrawer displays quota progress and conversations list',
        (tester) async {
      final sessions = [
        ChatSession(
          id: 's1',
          title: 'Exercice Polynôme',
          profileId: 'p1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: [
            ChatMessage(
              id: 'm1',
              sender: 'user',
              text: 'Aide-moi',
              timestamp: DateTime.now(),
            ),
          ],
        ),
        ChatSession(
          id: 's2',
          title: 'Étude de fonction',
          profileId: 'p1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: ChatHistoryDrawer(
              sessions: sessions,
              activeSessionId: 's1',
              onSelectSession: (_) {},
              onNewSession: () {},
              onDeleteSession: (_) {},
              onRenameSession: (_, __) {},
              onClearAll: () {},
            ),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Nouvelle discussion'), findsOneWidget);
      expect(find.text('2 / 10 chats'), findsOneWidget);
      expect(find.text('Exercice Polynôme'), findsOneWidget);
      expect(find.text('Étude de fonction'), findsOneWidget);
      expect(find.text('Effacer tout l\'historique'), findsOneWidget);
    });

    testWidgets('ChatMultimodalDock renders attachment button and text field',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMultimodalDock(
              onSend: (_) {},
              onSendWithAttachments: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('AiTutorChatScreen loads and displays ChatGPT/Gemini interface',
        (tester) async {
      final fake = _FakeStudentAuthNotifier(
        StudentAuthState(profiles: [profile], activeProfile: profile),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAuthProvider.overrideWith((ref) => fake),
          ],
          child: const MaterialApp(
            home: AiTutorChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar check
      expect(find.text('Tuteur pq learn'), findsOneWidget);
      expect(find.text('Multimodal'), findsOneWidget);

      // Empty state greeting check
      expect(find.text('Comment puis-je t\'aider aujourd\'hui ?'), findsOneWidget);

      // Quick starters check
      expect(find.text('Polynôme & Courbe'), findsOneWidget);
      expect(find.text('Comprendre un Théorème'), findsOneWidget);
      expect(find.text('Analyser un Exercice Photo'), findsOneWidget);
      expect(find.text('Méthode Dérivées & Limites'), findsOneWidget);

      // Drawer toggle button
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Dock check
      expect(find.byType(ChatMultimodalDock), findsOneWidget);
    });
  });
}
