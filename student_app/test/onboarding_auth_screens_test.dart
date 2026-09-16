import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/core/auth/student_auth_provider.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/core/theme/student_theme.dart';
import 'package:student_app/features/onboarding/screens/device_account_selector_screen.dart';
import 'package:student_app/features/onboarding/screens/login_code_entry_screen.dart';
import 'package:student_app/features/onboarding/screens/profile_switcher_screen.dart';
import 'package:student_app/features/onboarding/screens/student_login_screen.dart';
import 'package:student_app/core/auth/device_accounts_service.dart';

/// Notifier de substitution pour les tests : évite tout appel réseau réel (le vrai
/// [StudentAuthNotifier] appelle Supabase Auth dans `signIn`/`requestPasswordReset`), tout en
/// gardant le contrat public exact que les écrans utilisent.
///
/// Le constructeur parent tourne quand même et s'abonne à `onAuthStateChange` sur le faux projet
/// Supabase de test ; comme il n'y a aucune session réelle, cet abonnement livre un évènement
/// "aucun utilisateur" pendant le premier `pumpWidget`, ce qui écrase l'état fixé ici. [reassert]
/// doit donc être rappelé juste après `pumpWidget` (une seule fois : cet évènement initial ne se
/// reproduit pas ensuite).
class _FakeStudentAuthNotifier extends StudentAuthNotifier {
  _FakeStudentAuthNotifier({
    List<StudentProfile> profiles = const [],
    StudentProfile? activeProfile,
    this.resetResult,
  }) : _fixed = StudentAuthState(profiles: profiles, activeProfile: activeProfile) {
    state = _fixed;
  }

  final StudentAuthState _fixed;

  /// Valeur renvoyée par [requestPasswordReset] : `null` = succès, sinon message d'erreur.
  final String? resetResult;
  String? lastResetEmail;

  void reassert() => state = _fixed;

  @override
  Future<String?> requestPasswordReset(String email) async {
    lastResetEmail = email;
    return resetResult;
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Même convention que summary_sheet_access_test.dart : le viewport par défaut des tests widgets
  // est bien plus étroit qu'un téléphone réel et fait déborder tout écran non préparé pour ça.
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Login code entry never claims a fixed digit count that the real code format does not enforce',
    (tester) async {
      viewport(tester, 390);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: LoginCodeEntryScreen(
              account: DeviceKnownAccount(
                accountId: 'acc-1',
                firstName: 'Awa',
                lastName: 'Nkeng',
                email: 'awa@example.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('6 chiffres'), findsNothing);
      expect(find.text('Saisissez votre code personnel.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Device account selector reports a real read failure instead of silently showing zero accounts',
    (tester) async {
      viewport(tester, 390);
      // Donnée locale corrompue (jamais du JSON valide) : `listKnown()` lève une exception réelle
      // au lieu de retourner une liste vide — le test vérifie que l'UI la distingue bien d'un
      // simple « aucun compte connu ».
      SharedPreferences.setMockInitialValues({
        'student_device_accounts_v1': 'not-valid-json',
      });
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: DeviceAccountSelectorScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comptes enregistrés indisponibles'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      // Le repli honnête sur « aucun compte » (tuile « Ajouter un compte » seule) ne doit jamais
      // s'afficher pendant qu'une vraie erreur est en cours.
      expect(find.text('Ajouter un compte'), findsNothing);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Comptes enregistrés indisponibles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Profile switcher shows real subscription tier and school year, never a fabricated streak',
    (tester) async {
      viewport(tester, 390);
      final profile = StudentProfile(
        id: 'profile-1',
        accountId: 'acc-1',
        classNodeId: 'class-1',
        className: 'Terminale D',
        subscriptionTier: 'mensuel',
        schoolYear: '2025-2026',
      );
      final fake = _FakeStudentAuthNotifier(profiles: [profile], activeProfile: profile);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentAuthProvider.overrideWith((ref) => fake)],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const ProfileSwitcherScreen(),
          ),
        ),
      );
      // Voir la docstring de _FakeStudentAuthNotifier : l'abonnement réel du parent écrase l'état
      // fixé pendant ce premier pumpWidget (session absente du faux projet Supabase de test).
      fake.reassert();
      await tester.pumpAndSettle();
      // Le nom du profil (`profile.name` = `className`) apparaît à la fois comme titre de la
      // carte ET comme badge coloré sous le titre — un doublon de conception déjà présent avant
      // cette modification, pas introduit ici.
      expect(find.text('Terminale D'), findsNWidgets(2));
      expect(find.text('Année 2025-2026'), findsOneWidget);
      expect(find.text('Mensuel'), findsOneWidget);
      expect(find.textContaining('jours de suite'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('Student login — forgot password', () {
    Finder dialogEmailField() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    testWidgets('rejects an invalid email before calling Supabase', (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentAuthProvider.overrideWith((ref) => fake)],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const StudentLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogEmailField(), 'pas-un-email');
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Adresse email invalide.'), findsOneWidget);
      expect(fake.lastResetEmail, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sends a generic confirmation without confirming account existence', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(resetResult: null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentAuthProvider.overrideWith((ref) => fake)],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const StudentLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogEmailField(), 'eleve@example.com');
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(fake.lastResetEmail, 'eleve@example.com');
      expect(
        find.textContaining('Si un compte existe avec cette adresse'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('surfaces a real server error instead of a fake success', (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(resetResult: 'Service momentanément indisponible.');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentAuthProvider.overrideWith((ref) => fake)],
          child: MaterialApp(
            theme: StudentTheme.darkTheme,
            home: const StudentLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogEmailField(), 'eleve@example.com');
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Service momentanément indisponible.'), findsOneWidget);
      expect(
        find.textContaining('Si un compte existe avec cette adresse'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
