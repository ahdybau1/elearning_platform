// Garde d'appelant commune (Lot 1 de l'audit du 2026-11-22).
//
// Ces Edge Functions tournent avec la clé service_role : sans vérification, n'importe quel élève
// connecté (JWT valide) pouvait les appeler et consommer les quotas IA, ou relancer la correction
// de tentatives qui ne sont pas les siennes. Deux appelants légitimes seulement :
//   1. un autre service du backend (Edge Function, gateway, cron) qui présente la clé service_role ;
//   2. un administrateur actif (`admin_users.is_active = true`), via son JWT — cas de l'app admin,
//      et des relais `ai-agent-invoke` / `ai-workflow-run` / `ingestion-worker` qui transmettent
//      le JWT de l'admin.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.39.0";

const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function bearer(req: Request): string {
  const h = req.headers.get("Authorization") ?? req.headers.get("authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : "";
}

// Comparaison à temps constant (ne fuit pas la position du premier caractère différent).
function safeEqual(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function deny(status: number, message: string, cors: Record<string, string>): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/**
 * Renvoie `null` si l'appel est autorisé, sinon la `Response` d'erreur à retourner telle quelle.
 * `serviceOnly: true` : seule la clé service_role est acceptée (fonctions de cron).
 */
export async function requireAdminOrService(
  req: Request,
  supabase: SupabaseClient,
  cors: Record<string, string>,
  opts: { serviceOnly?: boolean } = {},
): Promise<Response | null> {
  const token = bearer(req);
  if (!token) return deny(401, "Authentification requise.", cors);

  if (safeEqual(token, SERVICE_ROLE_KEY)) return null;
  if (opts.serviceOnly) return deny(403, "Réservé aux services internes.", cors);

  const { data: userData, error } = await supabase.auth.getUser(token);
  if (error || !userData?.user) return deny(401, "Session invalide ou expirée.", cors);

  const { data: adminRow } = await supabase
    .from("admin_users")
    .select("id")
    .eq("auth_user_id", userData.user.id)
    .eq("is_active", true)
    .maybeSingle();
  if (!adminRow) return deny(403, "Accès réservé aux administrateurs actifs.", cors);

  return null;
}
