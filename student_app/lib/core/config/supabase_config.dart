import 'package:flutter_dotenv/flutter_dotenv.dart';

// Anon key publique par design (protégée par RLS, pas par le secret) — déjà exposée telle quelle
// dans admin_app/lib/main.dart ; reprise ici comme repli si .env est absent au premier lancement.
const fallbackSupabaseUrl = 'https://kdprnavvgzhnygovfyuw.supabase.co';
const fallbackSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtkcHJuYXZ2Z3pobnlnb3ZmeXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MDA0NDIsImV4cCI6MjEwMTk3NjQ0Mn0.Xei_VR0_umG0QDwfGs2GpQ2qDLG3o_tJX7WgU7T9ZXA';

String resolvedSupabaseUrl() =>
    (dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true) ? dotenv.env['SUPABASE_URL']! : fallbackSupabaseUrl;

String resolvedSupabaseAnonKey() =>
    (dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true) ? dotenv.env['SUPABASE_ANON_KEY']! : fallbackSupabaseAnonKey;
