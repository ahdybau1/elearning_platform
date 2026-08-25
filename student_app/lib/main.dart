import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/student_theme.dart';
import 'core/models/student_models.dart';
import 'core/config/supabase_config.dart';
import 'core/widgets/maintenance_gate.dart';
import 'core/auth/student_auth_provider.dart';
import 'core/auth/device_accounts_service.dart';
import 'features/onboarding/screens/onboarding_wizard_screen.dart';
import 'features/onboarding/screens/profile_switcher_screen.dart';
import 'features/onboarding/screens/student_login_screen.dart';
import 'features/onboarding/screens/device_account_selector_screen.dart';
import 'features/home/screens/main_navigation_screen.dart';
import 'features/courses/screens/chapters_list_screen.dart';
import 'features/courses/screens/lesson_reader_screen.dart';
import 'features/courses/screens/exercise_runner_screen.dart';
import 'features/ai_tutor/screens/ai_tutor_chat_screen.dart';
import 'features/exams/screens/mock_exam_arena_screen.dart';
import 'features/parent_portal/screens/parent_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = resolvedSupabaseUrl();
  final supabaseAnonKey = resolvedSupabaseAnonKey();

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  runApp(
    const ProviderScope(
      child: StudentElearningApp(),
    ),
  );
}

/// Point d'entrée réel de l'app : bascule entre connexion, inscription et sélecteur de profils
/// selon l'état réel de la session Supabase Auth — jamais de route de démarrage codée en dur (voir
/// la même logique côté admin_app, `SupabaseAuthGate` dans admin_app/lib/main.dart).
class StudentAuthGate extends ConsumerWidget {
  const StudentAuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: StudentTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!authState.hasSession) {
      // Un compte déjà connu sur CET appareil (déjà réellement authentifié par email + mot de passe
      // au moins une fois) permet le déverrouillage rapide par code personnel plutôt que de resaisir
      // le mot de passe à chaque fois — voir DeviceAccountsService pour la garantie de sécurité
      // exacte (le code ne vaut que pour le compte sélectionné, jamais pour en retrouver un autre).
      return FutureBuilder<List<DeviceKnownAccount>>(
        future: deviceAccountsService.listKnown(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: StudentTheme.backgroundDark,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!.isEmpty
              ? const StudentLoginScreen()
              : const DeviceAccountSelectorScreen();
        },
      );
    }
    if (authState.profiles.isEmpty) {
      // Session réelle mais profil élève pas encore complété (compte `accounts` manquant, ex. un
      // admin qui teste l'app) ou aucune classe encore choisie — l'assistant d'inscription adapte
      // lui-même l'étape à afficher selon ce qui manque réellement (voir
      // onboarding_wizard_screen.dart, _accountStepKind).
      return const OnboardingWizardScreen();
    }
    return const ProfileSwitcherScreen();
  }
}

class StudentElearningApp extends ConsumerWidget {
  const StudentElearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // §11.1/§11.2 : thème réellement piloté par les préférences du compte (clair/sombre/automatique
    // × contraste élevé) — `null` tant que non chargées (avant connexion, ou compte pas encore créé)
    // retombe sur le sombre historique, jamais un flash de thème incorrect.
    final settings = ref.watch(studentAuthProvider).settings ?? const AccountSettings();
    final theme = StudentTheme.resolve(
      mode: settings.themeMode,
      highContrast: settings.highContrast,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );

    return MaterialApp(
      title: 'E-Learning National Élève',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // `builder` reçoit déjà le Navigator construit par onGenerateRoute ci-dessous : contrairement
      // à SelectionArea (qui exige un ancêtre Overlay), MaintenanceGate n'a besoin de rien de plus
      // qu'un Consumer Riverpod, donc ce point d'accroche standard suffit pour bloquer TOUTES les
      // routes sans exception pendant la maintenance. La taille de police (§11.2) est appliquée ici
      // globalement via un TextScaler, indépendamment des couleurs du thème.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.fontScale)),
        child: MaintenanceGate(child: child!),
      ),
      home: const StudentAuthGate(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const StudentLoginScreen());
          case '/profiles':
            return MaterialPageRoute(builder: (_) => const ProfileSwitcherScreen());
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingWizardScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
          case '/chapters':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => ChaptersListScreen(
                subjectId: args['subjectId'] ?? '',
                subjectName: args['subjectName'] ?? 'Chapitres',
                classNodeId: args['classNodeId'] ?? '',
                subjectCode: args['subjectCode'] as String?,
              ),
            );
          case '/lesson-reader':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => LessonReaderScreen(
                chapterId: args['chapterId'] ?? '',
                chapterTitle: args['chapterTitle'] ?? 'Leçon',
              ),
            );
          case '/exercises':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => ExerciseRunnerScreen(
                chapterId: args['chapterId'] ?? '',
                chapterTitle: args['chapterTitle'] ?? 'Quiz',
              ),
            );
          case '/ai-tutor':
            return MaterialPageRoute(builder: (_) => const AiTutorChatScreen());
          case '/mock-arena':
            return MaterialPageRoute(builder: (_) => const MockExamArenaScreen());
          case '/parent-portal':
            return MaterialPageRoute(builder: (_) => const ParentDashboardScreen());
          default:
            return MaterialPageRoute(builder: (_) => const ProfileSwitcherScreen());
        }
      },
    );
  }
}
