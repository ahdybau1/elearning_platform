import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/student_theme.dart';
import 'core/widgets/maintenance_gate.dart';
import 'core/auth/student_auth_provider.dart';
import 'features/onboarding/screens/onboarding_wizard_screen.dart';
import 'features/onboarding/screens/profile_switcher_screen.dart';
import 'features/onboarding/screens/student_login_screen.dart';
import 'features/home/screens/main_navigation_screen.dart';
import 'features/courses/screens/chapters_list_screen.dart';
import 'features/courses/screens/lesson_reader_screen.dart';
import 'features/courses/screens/exercise_runner_screen.dart';
import 'features/ai_tutor/screens/ai_tutor_chat_screen.dart';
import 'features/exams/screens/mock_exam_arena_screen.dart';
import 'features/parent_portal/screens/parent_dashboard_screen.dart';

// Anon key publique par design (protégée par RLS, pas par le secret) — déjà exposée telle quelle
// dans admin_app/lib/main.dart ; reprise ici comme repli si .env est absent au premier lancement.
const _fallbackSupabaseUrl = 'https://kdprnavvgzhnygovfyuw.supabase.co';
const _fallbackSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtkcHJuYXZ2Z3pobnlnb3ZmeXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MDA0NDIsImV4cCI6MjEwMTk3NjQ0Mn0.Xei_VR0_umG0QDwfGs2GpQ2qDLG3o_tJX7WgU7T9ZXA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = (dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true)
      ? dotenv.env['SUPABASE_URL']!
      : _fallbackSupabaseUrl;
  final supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true)
      ? dotenv.env['SUPABASE_ANON_KEY']!
      : _fallbackSupabaseAnonKey;

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
      return const StudentLoginScreen();
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

class StudentElearningApp extends StatelessWidget {
  const StudentElearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Learning National Élève',
      debugShowCheckedModeBanner: false,
      theme: StudentTheme.darkTheme,
      // `builder` reçoit déjà le Navigator construit par onGenerateRoute ci-dessous : contrairement
      // à SelectionArea (qui exige un ancêtre Overlay), MaintenanceGate n'a besoin de rien de plus
      // qu'un Consumer Riverpod, donc ce point d'accroche standard suffit pour bloquer TOUTES les
      // routes sans exception pendant la maintenance.
      builder: (context, child) => MaintenanceGate(child: child!),
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
