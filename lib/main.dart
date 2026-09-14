import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_provider.dart';
import 'features/dashboard/screens/main_admin_layout.dart';
import 'features/auth/screens/login_screen.dart';

const _fallbackSupabaseUrl = 'https://kdprnavvgzhnygovfyuw.supabase.co';
const _fallbackSupabaseAnonKey =
    'sb_publishable_KyOfBUnlxvLQBeqzzV-1Wg_kLjmxbVi';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.public');

  final supabaseUrl = (dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true)
      ? dotenv.env['SUPABASE_URL']!
      : _fallbackSupabaseUrl;
  final supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true)
      ? dotenv.env['SUPABASE_ANON_KEY']!
      : _fallbackSupabaseAnonKey;

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    debug: true,
  );
  // Sans ce wrapper, aucun texte de l'application (emails, UUID, messages d'erreur...) n'est
  // sélectionnable au clic-glissé : les `Text` Flutter ne sont pas sélectionnables par défaut,
  // contrairement à une page web classique. Un essai pour étendre cette couverture aux modales
  // (`showDialog` pousse une route séparée, donc hors de portée d'un `SelectionArea` posé sur
  // `home:` seul) via un Overlay+Localizations manuels avant MaterialApp s'est révélé instable —
  // `Localizations` ne résout ses delegates qu'après un microtask, donc `SelectionArea` échoue sur
  // sa toute première frame (`No MaterialLocalizations found`, vérifié en relançant l'app). On
  // revient donc à la version stable, qui couvre déjà tout le contenu des pages/listes (l'essentiel
  // de ce qu'un admin copie) ; seul le texte à l'intérieur des boîtes de dialogue reste hors
  // couverture — à traiter séparément et plus précisément si besoin.
  runApp(const ProviderScope(child: ElearningAdminApp()));
}

class ElearningAdminApp extends ConsumerWidget {
  const ElearningAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'pq learn Admin HQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SelectionArea(child: SupabaseAuthGate()),
    );
  }
}

class SupabaseAuthGate extends ConsumerWidget {
  const SupabaseAuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      data: (user) =>
          user != null ? const MainAdminLayout() : const LoginScreen(),
      loading: () => const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) {
        debugPrint('AuthGate connection/permission error: $err');
        return const LoginScreen();
      },
    );
  }
}
