import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/core/auth/session_guard_provider.dart';
import 'package:student_app/core/auth/student_auth_provider.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/features/home/screens/main_navigation_screen.dart';
import 'package:student_app/main.dart';

class _FakeStudentAuthNotifier extends StudentAuthNotifier {
  _FakeStudentAuthNotifier(this._fixed) {
    state = _fixed;
  }
  final StudentAuthState _fixed;
  void reassert() => state = _fixed;
}

/// Fake minimal : ne touche jamais au réseau (contrairement au vrai `SessionGuardNotifier` qui
/// insère une vraie ligne dans `sessions`) — expose juste l'état d'éviction voulu par le test.
class _FakeSessionGuardNotifier extends SessionGuardNotifier {
  _FakeSessionGuardNotifier(super.ref, bool isEvicted) {
    state = SessionGuardState(isEvicted: isEvicted);
  }
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

  final account = StudentAccount(
    id: 'account-1',
    authUserId: 'auth-1',
    email: 'awa@example.com',
    firstName: 'Awa',
    lastName: 'Nkeng',
  );
  final profile = StudentProfile(
    id: 'profile-1',
    accountId: 'account-1',
    classNodeId: 'class-1',
    className: 'Terminale D',
    schoolYear: '2025-2026',
  );

  testWidgets(
    'an evicted session shows the exact cahier message and blocks the app, even fully authenticated',
    (tester) async {
      viewport(tester, 390);
      final authFake = _FakeStudentAuthNotifier(
        StudentAuthState(
          account: account,
          profiles: [profile],
          activeProfile: profile,
          sessionEmail: account.email,
          hasUnlockedThisBoot: true,
          hasConfirmedProfileThisBoot: true,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAuthProvider.overrideWith((ref) => authFake),
            sessionGuardProvider.overrideWith(
              (ref) => _FakeSessionGuardNotifier(ref, true),
            ),
          ],
          child: const MaterialApp(home: StudentAuthGate()),
        ),
      );
      authFake.reassert();
      await tester.pumpAndSettle();
      expect(
        find.text('Compte utilisé sur un autre appareil — reconnectez-vous pour reprendre l\'accès'),
        findsOneWidget,
      );
      expect(find.byType(MainNavigationScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a genuinely active (non-evicted) session reaches the real app, no eviction message',
    (tester) async {
      viewport(tester, 390);
      final authFake = _FakeStudentAuthNotifier(
        StudentAuthState(
          account: account,
          profiles: [profile],
          activeProfile: profile,
          sessionEmail: account.email,
          hasUnlockedThisBoot: true,
          hasConfirmedProfileThisBoot: true,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAuthProvider.overrideWith((ref) => authFake),
            sessionGuardProvider.overrideWith(
              (ref) => _FakeSessionGuardNotifier(ref, false),
            ),
          ],
          child: const MaterialApp(home: StudentAuthGate()),
        ),
      );
      authFake.reassert();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Compte utilisé sur un autre appareil'),
        findsNothing,
      );
      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
