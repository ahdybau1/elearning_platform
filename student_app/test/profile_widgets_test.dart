import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/core/auth/student_auth_provider.dart';
import 'package:student_app/core/models/student_models.dart';
import 'package:student_app/core/providers/student_providers.dart';
import 'package:student_app/core/services/student_supabase_service.dart';
import 'package:student_app/core/theme/student_theme.dart';
import 'package:student_app/features/profile/screens/student_profile_screen.dart';
import 'package:student_app/features/profile/widgets/archive_class_dialog.dart';
import 'package:student_app/features/profile/widgets/archived_classes_section.dart';
import 'package:student_app/features/profile/widgets/edit_profile_dialog.dart';
import 'package:student_app/features/profile/widgets/followed_classes_section.dart';
import 'package:student_app/features/profile/widgets/login_code_card.dart';
import 'package:student_app/features/profile/widgets/parent_invite_card.dart';
import 'package:student_app/features/profile/widgets/profile_identity_card.dart';

/// Notifier de substitution — même principe que `onboarding_auth_screens_test.dart` : le vrai
/// `StudentAuthNotifier` s'abonne à `onAuthStateChange` sur le faux projet Supabase de test, ce qui
/// écrase l'état fixé ici pendant le premier `pumpWidget` (aucune session réelle) ; [reassert]
/// restaure l'état voulu juste après.
class _FakeStudentAuthNotifier extends StudentAuthNotifier {
  _FakeStudentAuthNotifier({
    StudentAccount? account,
    List<StudentProfile> profiles = const [],
    StudentProfile? activeProfile,
    this.updateProfileResult,
    this.setLoginCodeResult,
    this.myLoginCode,
    this.archiveResult,
    this.reactivateResult,
  }) : _fixed = StudentAuthState(
         account: account,
         profiles: profiles,
         activeProfile: activeProfile,
       ) {
    state = _fixed;
  }

  final StudentAuthState _fixed;
  void reassert() => state = _fixed;

  final String? updateProfileResult;
  final String? setLoginCodeResult;
  final String? myLoginCode;
  final String? archiveResult;
  final String? reactivateResult;

  Map<String, dynamic>? lastProfileUpdate;
  String? lastSetCode;
  String? lastArchivedProfileId;
  String? lastReactivatedProfileId;

  @override
  Future<String?> updateProfileInfo({
    required String firstName,
    required String lastName,
    String? schoolName,
    DateTime? birthDate,
  }) async {
    lastProfileUpdate = {
      'firstName': firstName,
      'lastName': lastName,
      'schoolName': schoolName,
      'birthDate': birthDate,
    };
    return updateProfileResult;
  }

  @override
  Future<String?> setLoginCode(String code) async {
    lastSetCode = code;
    return setLoginCodeResult;
  }

  @override
  Future<String?> fetchMyLoginCode() async => myLoginCode;

  @override
  Future<String?> archiveProfile(String profileId) async {
    lastArchivedProfileId = profileId;
    return archiveResult;
  }

  @override
  Future<String?> reactivateProfile(String profileId) async {
    lastReactivatedProfileId = profileId;
    return reactivateResult;
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

  Future<_FakeStudentAuthNotifier> pumpScreen(
    WidgetTester tester,
    _FakeStudentAuthNotifier fake,
    Widget child, {
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentAuthProvider.overrideWith((ref) => fake),
          ...extraOverrides,
        ],
        child: MaterialApp(theme: StudentTheme.darkTheme, home: child),
      ),
    );
    fake.reassert();
    await tester.pumpAndSettle();
    return fake;
  }

  group('ProfileIdentityCard', () {
    testWidgets('shows account info and enables edit when an account exists', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(account: account);
      await pumpScreen(
        tester,
        fake,
        Scaffold(body: ProfileIdentityCard(account: account)),
      );
      expect(find.text('Awa Nkeng'), findsOneWidget);
      expect(find.text('awa@example.com'), findsOneWidget);
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disables edit when there is no account yet', (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier();
      await pumpScreen(
        tester,
        fake,
        const Scaffold(body: ProfileIdentityCard(account: null)),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditProfileDialog', () {
    testWidgets('blocks submission when the required names are empty', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(account: account);
      await pumpScreen(
        tester,
        fake,
        Builder(
          builder: (context) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => EditProfileDialog.show(context, ref, account),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Prénom *'),
        '   ',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(fake.lastProfileUpdate, isNull);
      expect(find.text('Modifier mes informations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submits real values and reports a server failure honestly', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        account: account,
        updateProfileResult: 'Modification du profil impossible.',
      );
      await pumpScreen(
        tester,
        fake,
        Builder(
          builder: (context) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => EditProfileDialog.show(context, ref, account),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Établissement scolaire (optionnel)'),
        'Lycée Général Leclerc',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(fake.lastProfileUpdate, isNotNull);
      expect(fake.lastProfileUpdate!['firstName'], 'Awa');
      expect(fake.lastProfileUpdate!['schoolName'], 'Lycée Général Leclerc');
      expect(
        find.text('Modification du profil impossible.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginCodeCard', () {
    testWidgets('« Voir » shows the real fetched code, never a placeholder', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        account: account,
        myLoginCode: 'monCode123',
      );
      await pumpScreen(
        tester,
        fake,
        const Scaffold(body: LoginCodeCard()),
      );
      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();
      expect(find.text('monCode123'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Voir » is honest when no code has been set', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(account: account, myLoginCode: null);
      await pumpScreen(
        tester,
        fake,
        const Scaffold(body: LoginCodeCard()),
      );
      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun code défini pour l\'instant.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '« Définir / Changer » rejects mismatched codes before calling Supabase',
      (tester) async {
        viewport(tester, 390);
        final fake = _FakeStudentAuthNotifier(account: account);
        await pumpScreen(
          tester,
          fake,
          const Scaffold(body: LoginCodeCard()),
        );
        await tester.tap(find.text('Définir / Changer'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Nouveau code (4 à 40 caractères)'),
          'abcd1234',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmer le code'),
          'different',
        );
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        expect(
          find.text('Les deux codes ne correspondent pas.'),
          findsOneWidget,
        );
        expect(fake.lastSetCode, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '« Définir / Changer » submits matching codes and reports a real server error',
      (tester) async {
        viewport(tester, 390);
        final fake = _FakeStudentAuthNotifier(
          account: account,
          setLoginCodeResult: 'Code déjà utilisé, choisissez-en un autre.',
        );
        await pumpScreen(
          tester,
          fake,
          const Scaffold(body: LoginCodeCard()),
        );
        await tester.tap(find.text('Définir / Changer'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Nouveau code (4 à 40 caractères)'),
          'abcd1234',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmer le code'),
          'abcd1234',
        );
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        expect(fake.lastSetCode, 'abcd1234');
        expect(
          find.text('Code déjà utilisé, choisissez-en un autre.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ParentInviteCard', () {
    testWidgets('shows the real generated invite code', (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(account: account);
      await pumpScreen(
        tester,
        fake,
        const Scaffold(body: ParentInviteCard(profileId: 'profile-1')),
        extraOverrides: [
          parentLinkCodeProvider.overrideWith((ref, id) async => 'INV42'),
        ],
      );
      expect(find.text('INV42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('redeeming a code reports a real failure without fake success', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(account: account);
      await pumpScreen(
        tester,
        fake,
        const Scaffold(body: ParentInviteCard(profileId: 'profile-1')),
        extraOverrides: [
          parentLinkCodeProvider.overrideWith((ref, id) async => 'INV42'),
          studentSupabaseServiceProvider.overrideWithValue(
            _FailingRedeemService(),
          ),
        ],
      );
      await tester.enterText(find.byType(TextField), 'BADCODE');
      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();
      expect(find.text('Code invalide ou liaison impossible.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Archive / reactivate flow', () {
    final profileA = StudentProfile(
      id: 'p1',
      accountId: 'account-1',
      classNodeId: 'class-1',
      className: 'Terminale D',
      schoolYear: '2025-2026',
    );
    final profileB = StudentProfile(
      id: 'p2',
      accountId: 'account-1',
      classNodeId: 'class-2',
      className: 'Première D',
      schoolYear: '2025-2026',
    );

    testWidgets(
      'archiving reports a real server failure without a fake success message',
      (tester) async {
        viewport(tester, 390);
        final fake = _FakeStudentAuthNotifier(
          account: account,
          profiles: [profileA, profileB],
          archiveResult: 'Archivage impossible pour le moment.',
        );
        await pumpScreen(
          tester,
          fake,
          Scaffold(
            body: FollowedClassesSection(
              profiles: [profileA, profileB],
              activeProfileId: profileA.id,
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.archive_outlined).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archiver'));
        await tester.pumpAndSettle();
        expect(fake.lastArchivedProfileId, profileA.id);
        expect(
          find.text('Archivage impossible pour le moment.'),
          findsOneWidget,
        );
        expect(find.text('Classe archivée.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'confirming ArchiveClassDialog calls archiveProfile with the right id',
      (tester) async {
        viewport(tester, 390);
        final fake = _FakeStudentAuthNotifier(
          account: account,
          profiles: [profileA, profileB],
        );
        await pumpScreen(
          tester,
          fake,
          Scaffold(
            body: FollowedClassesSection(
              profiles: [profileA, profileB],
              activeProfileId: profileA.id,
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.archive_outlined).first);
        await tester.pumpAndSettle();
        expect(find.byType(ArchiveClassDialog), findsOneWidget);
        await tester.tap(find.text('Archiver'));
        await tester.pumpAndSettle();
        expect(fake.lastArchivedProfileId, profileA.id);
        expect(find.text('Classe archivée.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cancelling ArchiveClassDialog never calls archiveProfile', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        account: account,
        profiles: [profileA, profileB],
      );
      await pumpScreen(
        tester,
        fake,
        Scaffold(
          body: FollowedClassesSection(
            profiles: [profileA, profileB],
            activeProfileId: profileA.id,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.archive_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(fake.lastArchivedProfileId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reactivating an archived class calls reactivateProfile', (
      tester,
    ) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(account: account);
      await pumpScreen(
        tester,
        fake,
        const Scaffold(body: ArchivedClassesSection(accountId: 'account-1')),
        extraOverrides: [
          archivedProfilesProvider.overrideWith(
            (ref, id) async => [profileB],
          ),
        ],
      );
      expect(find.text('Première D'), findsOneWidget);
      await tester.tap(find.text('Réactiver'));
      await tester.pumpAndSettle();
      expect(fake.lastReactivatedProfileId, profileB.id);
      expect(find.text('Classe réactivée.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'reactivating reports a real server failure without a fake success message',
      (tester) async {
        viewport(tester, 390);
        final fake = _FakeStudentAuthNotifier(
          account: account,
          reactivateResult: 'Réactivation impossible pour le moment.',
        );
        await pumpScreen(
          tester,
          fake,
          const Scaffold(body: ArchivedClassesSection(accountId: 'account-1')),
          extraOverrides: [
            archivedProfilesProvider.overrideWith(
              (ref, id) async => [profileB],
            ),
          ],
        );
        await tester.tap(find.text('Réactiver'));
        await tester.pumpAndSettle();
        expect(fake.lastReactivatedProfileId, profileB.id);
        expect(
          find.text('Réactivation impossible pour le moment.'),
          findsOneWidget,
        );
        expect(find.text('Classe réactivée.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'StudentProfileScreen orchestrates every section without crashing',
    (tester) async {
      viewport(tester, 390);
      final fake = _FakeStudentAuthNotifier(
        account: account,
        profiles: [
          StudentProfile(
            id: 'p1',
            accountId: 'account-1',
            classNodeId: 'class-1',
            className: 'Terminale D',
            schoolYear: '2025-2026',
          ),
        ],
      );
      await pumpScreen(
        tester,
        fake,
        const StudentProfileScreen(),
        extraOverrides: [
          parentLinkCodeProvider.overrideWith((ref, id) async => 'INV42'),
          archivedProfilesProvider.overrideWith((ref, id) async => const []),
        ],
      );
      expect(find.text('Mon Profil'), findsOneWidget);
      expect(find.text('Mes Classes Suivies'), findsOneWidget);
      expect(find.text('Mes Réussites & Assiduité'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FailingRedeemService extends StudentSupabaseService {
  _FailingRedeemService() : super(Supabase.instance.client);

  @override
  Future<String?> redeemParentInviteCode(String code) async =>
      'Code invalide ou liaison impossible (test).';
}
