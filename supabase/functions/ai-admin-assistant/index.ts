// AdminAssistantAgent (AIA-AGT-021, IA-013 — docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7/§22), porté
// depuis gateway/app/agents/admin_assistant_agent.py (2026-09-06) : le Gateway Python n'est déployé
// nulle part (uvicorn local uniquement) — aucun agent gateway_native n'était réellement joignable en
// dehors d'une session de développement. Réécrit en Deno pour rester à coût zéro (Edge Function déjà
// gratuite/déployée en continu).
//
// Strictement en lecture, zéro mutation (interdit explicite du cahier : SQL arbitraire, modification
// RLS, action mutante sans confirmation). Synthèse "ce qui mérite l'attention de l'admin maintenant" —
// n'existe nulle part comme vue unique (Agents IA & Coûts / Tickets Support / File de Validation sont
// des écrans séparés dans admin_app).
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // Réservé admin — vérifié via le JWT de l'appelant (admin_app envoie toujours sa propre
    // session), même garde que les autres fonctions admin-only de ce projet.
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData } = await supabase.auth.getUser(jwt);
    if (!userData?.user?.id) {
      return new Response(JSON.stringify({ error: "Session invalide." }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const { data: admin } = await supabase
      .from("admin_users").select("id").eq("auth_user_id", userData.user.id).eq("is_active", true).maybeSingle();
    if (!admin) {
      return new Response(JSON.stringify({ error: "Réservé aux comptes admin." }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const failureLimit = Number(body.failure_limit ?? 10);

    const [failuresRes, ticketsRes, validationRes] = await Promise.all([
      supabase.from("ai_agent_calls").select("agent_type,error_message,created_at")
        .eq("status", "failed").order("created_at", { ascending: false }).limit(failureLimit),
      supabase.from("support_tickets").select("category").in("status", ["ouvert", "en_cours"]),
      supabase.from("validation_queue").select("id").eq("status", "en_attente"),
    ]);

    const openTicketsByCategory: Record<string, number> = {};
    for (const row of ticketsRes.data ?? []) {
      openTicketsByCategory[row.category] = (openTicketsByCategory[row.category] ?? 0) + 1;
    }

    return new Response(
      JSON.stringify({
        recent_ai_failures: failuresRes.data ?? [],
        open_support_tickets_by_category: openTicketsByCategory,
        pending_content_validation: (validationRes.data ?? []).length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("AI Admin Assistant Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message ?? String(error) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
