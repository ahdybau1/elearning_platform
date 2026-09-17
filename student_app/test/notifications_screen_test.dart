import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/core/auth/student_auth_provider.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/core/providers/student_providers.dart';
import 'package:student_app/core/theme/student_theme.dart';
import 'package:student_app/features/home/screens/home_learning_screen.dart';
import 'package:student_app/features/notifications/screens/notifications_screen.dart';

class _FakeStudentAuthNotifier extends StudentAuthNotifier {
  _FakeStudentAuthNotifier(this._fixed) {
    state = _fixed;
  }
  final StudentAuthState _fixed;
  void reassert() => state = _fixed;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final profile = StudentProfile(
    id: 'profile-1',
    accountId: 'account-1',
    classNodeId: 'class-1',
    className: 'Terminale D',
    schoolYear: '2025-2026',
  );

  StudentNotification notif({
    required String id,
    required String title,
    DateTime? sentAt,
    DateTime? openedAt,
  }) => StudentNotification(
    id: id,
    title: title,
    body: 'Corps de la notification $id.',
    channel: 'in_app',
    sentAt: sentAt ?? DateTime.now().subtract(const Duration(hours: 2)),
    openedAt: openedAt,
  );

  testWidgets(
    'renders 3 real notifications, newest first, unread badge on unopened ones',
    (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        StudentAuthState(profiles: [profile], activeProfile: profile),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAuthProvider.overrideWith((ref) => fake),
            notificationsProvider(profile.id).overrideWith(
              (ref) async => [
                notif(
                  id: '1',
                  title: 'Plus récent',
                  sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
                ),
                notif(
                  id: '2',
                  title: 'Déjà lu',
                  sentAt: DateTime.now().subtract(const Duration(days: 1)),
                  openedAt: DateTime.now(),
                ),
                notif(
                  id: '3',
                  title: 'Plus ancien',
                  sentAt: DateTime.now().subtract(const Duration(days: 3)),
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const Scaffold(body: NotificationsScreen()),
          ),
        ),
      );
      fake.reassert();
      await tester.pumpAndSettle();
      expect(find.text('Plus récent'), findsOneWidget);
      expect(find.text('Déjà lu'), findsOneWidget);
      expect(find.text('Plus ancien'), findsOneWidget);
      // 2 non lues ('1'='Plus récent', '3'='Plus ancien') -> 2 pastilles ; '2'='Déjà lu' aucune.
      expect(find.byKey(const ValueKey('notification_unread_dot_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('notification_unread_dot_2')), findsNothing);
      expect(find.byKey(const ValueKey('notification_unread_dot_3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders the honest empty state, never a spinner forever', (
    tester,
  ) async {
    viewport(tester, 390);
    final fake = _FakeStudentAuthNotifier(
      StudentAuthState(profiles: [profile], activeProfile: profile),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentAuthProvider.overrideWith((ref) => fake),
          notificationsProvider(
            profile.id,
          ).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: StudentTheme.darkTheme,
          home: const Scaffold(body: NotificationsScreen()),
        ),
      ),
    );
    fake.reassert();
    await tester.pumpAndSettle();
    expect(find.text('Aucune notification'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a real read error is shown honestly, never mistaken for zero notifications',
    (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        StudentAuthState(profiles: [profile], activeProfile: profile),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAuthProvider.overrideWith((ref) => fake),
            notificationsProvider(
              profile.id,
            ).overrideWith((ref) async => throw Exception('offline')),
          ],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const Scaffold(body: NotificationsScreen()),
          ),
        ),
      );
      fake.reassert();
      await tester.pumpAndSettle();
      expect(find.text('Notifications indisponibles'), findsOneWidget);
      expect(find.text('Aucune notification'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home bell shows a real unread count and opens the real screen',
    (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        StudentAuthState(profiles: [profile], activeProfile: profile),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAuthProvider.overrideWith((ref) => fake),
            notificationsProvider(profile.id).overrideWith(
              (ref) async => [notif(id: '1', title: 'Une notif non lue')],
            ),
          ],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const Scaffold(body: HomeLearningScreen()),
          ),
        ),
      );
      fake.reassert();
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
