// WP4 — Test de connexion réel d'une intégration (consigne #5). Admin uniquement.
// Écrit `connected` / `last_check_at` / `last_status` / `last_error` / `last_latency_ms` sur la
// ligne `integrations`. N'expose jamais de secret : lit les function-secrets côté serveur, ne
// renvoie que le verdict.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

type Verdict = { status: "ok" | "error" | "not_configured"; detail: string; latency_ms: number };

async function checkGemini(): Promise<Verdict> {
  if (!GEMINI_API_KEY) return { status: "not_configured", detail: "GEMINI_API_KEY absente côté serveur.", latency_ms: 0 };
  const t = Date.now();
  try {
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}`,
      { signal: AbortSignal.timeout(12000) },
    );
    const latency = Date.now() - t;
    if (r.ok) {
      const data = await r.json();
      const n = Array.isArray(data.models) ? data.models.length : 0;
      return { status: "ok", detail: `Connexion OK — ${n} modèle(s) accessibles.`, latency_ms: latency };
    }
    const body = (await r.text()).slice(0, 200);
    return { status: "error", detail: `HTTP ${r.status} : ${body}`, latency_ms: latency };
  } catch (e: any) {
    return { status: "error", detail: `Injoignable : ${e?.message ?? e}`, latency_ms: Date.now() - t };
  }
}

async function checkStorage(): Promise<Verdict> {
  const t = Date.now();
  try {
    const { data, error } = await admin.storage.listBuckets();
    const latency = Date.now() - t;
    if (error) return { status: "error", detail: error.message, latency_ms: latency };
    return { status: "ok", detail: `Storage OK — ${data?.length ?? 0} bucket(s) : ${(data ?? []).map((b) => b.name).join(", ")}.`, latency_ms: latency };
  } catch (e: any) {
    return { status: "error", detail: `${e?.message ?? e}`, latency_ms: Date.now() - t };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { data: userData } = await admin.auth.getUser(jwt);
    const { data: adminRow } = userData?.user?.id
      ? await admin.from("admin_users").select("id").eq("auth_user_id", userData.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) return json({ error: "Accès réservé aux administrateurs actifs." }, 403);

    const { key } = await req.json().catch(() => ({}));
    if (!key) return json({ error: "Paramètre « key » manquant." }, 400);

    const { data: integ } = await admin.from("integrations").select("*").eq("key", key).maybeSingle();
    if (!integ) return json({ error: `Intégration inconnue : ${key}` }, 404);

    let verdict: Verdict;
    switch (key) {
      case "gemini_generative":
      case "gemini_embeddings":
        verdict = await checkGemini();
        break;
      case "supabase_storage":
        verdict = await checkStorage();
        break;
      case "payment_mobile_money":
        verdict = {
          status: "not_configured",
          detail: "Aucun contrat agrégateur Mobile Money. Le webhook payment-webhook est déployé mais aucun flux réel n'est branché.",
          latency_ms: 0,
        };
        break;
      default:
        verdict = { status: "not_configured", detail: "Aucun test de connexion défini pour cette intégration.", latency_ms: 0 };
    }

    await admin.from("integrations").update({
      connected: verdict.status === "ok",
      last_check_at: new Date().toISOString(),
      last_status: verdict.status,
      last_error: verdict.status === "ok" ? null : verdict.detail,
      last_latency_ms: verdict.latency_ms,
    }).eq("key", key);

    return json({ key, status: verdict.status, detail: verdict.detail, latency_ms: verdict.latency_ms });
  } catch (err: any) {
    return json({ error: err?.message ?? "Erreur interne du test de connexion." }, 500);
  }
});
