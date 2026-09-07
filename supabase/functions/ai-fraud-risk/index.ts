// FraudRiskAgent (AIA-AGT-025, IA-013), porté depuis gateway/app/agents/fraud_risk_agent.py
// (2026-09-06) — même motif : le Gateway Python n'est jamais déployé.
//
// UN SEUL signal — partage d'appareil entre comptes distincts (`sessions.device_fingerprint`,
// migration 01, dont le commentaire dit explicitement « anti-partage de compte »). Choisi parce que
// le schéma le prévoit déjà, pas inventé. `confidence` reste une heuristique déclarée, jamais une
// probabilité mesurée — un signal à faire vérifier par un humain, jamais une sanction automatique
// (règle explicite du cahier). Réservé aux rôles super_admin/admin_pays (données sensibles).
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SHARED_DEVICE_MIN_ACCOUNTS = 2;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData } = await supabase.auth.getUser(jwt);
    const { data: admin } = userData?.user?.id
      ? await supabase.from("admin_users").select("role").eq("auth_user_id", userData.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!admin || !["super_admin", "admin_pays"].includes(admin.role)) {
      return new Response(JSON.stringify({ error: "Réservé aux rôles super_admin/admin_pays." }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: sessions } = await supabase
      .from("sessions").select("account_id,device_fingerprint,platform,last_active_at").eq("is_active", true);

    const byFingerprint = new Map<string, { account_id: string; platform: string; last_active_at: string }[]>();
    for (const s of sessions ?? []) {
      const list = byFingerprint.get(s.device_fingerprint) ?? [];
      list.push(s);
      byFingerprint.set(s.device_fingerprint, list);
    }

    const signals = [];
    for (const [fingerprint, sess] of byFingerprint) {
      const distinctAccounts = [...new Set(sess.map((s) => s.account_id))].sort();
      if (distinctAccounts.length < SHARED_DEVICE_MIN_ACCOUNTS) continue;
      signals.push({
        signal_type: "shared_device",
        device_fingerprint: fingerprint,
        accounts: distinctAccounts,
        evidence: sess.map((s) => ({ account_id: s.account_id, platform: s.platform, last_active_at: s.last_active_at })),
        confidence: Math.min(0.5 + 0.1 * (distinctAccounts.length - 2), 0.9),
        recommended_review: "Vérifier s'il s'agit d'un appareil familial légitime ou d'un partage d'abonnement.",
      });
    }
    signals.sort((a, b) => b.confidence - a.confidence);

    return new Response(JSON.stringify({ signals: signals.slice(0, 20) }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("AI Fraud Risk Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message ?? String(error) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
