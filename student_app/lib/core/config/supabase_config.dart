import 'package:flutter_dotenv/flutter_dotenv.dart';

// Anon key publique par design (protégée par RLS, pas par le secret) — déjà exposée telle quelle
// dans admin_app/lib/main.dart ; reprise ici comme repli si .env est absent au premier lancement.
const fallbackSupabaseUrl = 'https://kdprnavvgzhnygovfyuw.supabase.co';
const fallbackSupabaseAnonKey =
    'sb_publishable_KyOfBUnlxvLQBeqzzV-1Wg_kLjmxbVi';

String resolvedSupabaseUrl() =>
    (dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true) ? dotenv.env['SUPABASE_URL']! : fallbackSupabaseUrl;

String resolvedSupabaseAnonKey() =>
    (dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true) ? dotenv.env['SUPABASE_ANON_KEY']! : fallbackSupabaseAnonKey;
