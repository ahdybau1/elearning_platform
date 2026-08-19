import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/student_theme.dart';
import 'features/onboarding/screens/onboarding_wizard_screen.dart';
import 'features/onboarding/screens/profile_switcher_screen.dart';
import 'features/home/screens/main_navigation_screen.dart';
import 'features/courses/screens/chapters_list_screen.dart';
import 'features/courses/screens/lesson_reader_screen.dart';
import 'features/courses/screens/exercise_runner_screen.dart';
import 'features/ai_tutor/screens/ai_tutor_chat_screen.dart';
import 'features/exams/screens/mock_exam_arena_screen.dart';
import 'features/parent_portal/screens/parent_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase initialization with project credentials
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://xyzcompany.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
    ),
  );

  runApp(
    const ProviderScope(
      child: StudentElearningApp(),
    ),
  );
}

class StudentElearningApp extends StatelessWidget {
  const StudentElearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Learning National Élève',
      debugShowCheckedModeBanner: false,
      theme: StudentTheme.darkTheme,
      initialRoute: '/profiles',
      onGenerateRoute: (settings) {
        switch (settings.name) {
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
