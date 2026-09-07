// SupportTriageAgent (AIA-AGT-022, IA-013), porté depuis gateway/app/agents/support_triage_agent.py
// (2026-09-06) — même motif que ai-admin-assistant : le Gateway Python n'est jamais déployé.
//
// Déterministe par mots-clés, pas de LLM (cohérent avec la préférence du cahier pour un moteur
// mécanique quand il suffit). `category` est déjà choisie par le demandeur à la création du ticket
// (contrainte CHECK réelle) — cet agent calcule PRIORITÉ et ROUTAGE, jamais réécrits ailleurs.
// `suggested_response` reste `null` : aucune base de solutions documentées n'existe sur ce projet —
// une réponse inventée serait pire qu'aucune réponse. N'écrit JAMAIS `assigned_to` lui-même.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const URGENT_KEYWORDS = [
  "urgent", "bloqué", "bloquée", "impossible de payer", "piraté", "piratée",
  "compte suspendu", "perdu mon accès", "arnaque", "fraude", "ne fonctionne plus du tout",
];
const ROUTING_BY_CATEGORY: Record<string, string> = {
  paiement: "equipe_facturation",
  technique: "equipe_technique",
  contenu: "equipe_pedagogique",
  autre: "equipe_support_generale",
};

function detectPriority(subject: string, description: string): string {
  const text = `${subject} ${description}`.toLowerCase();
  return URGENT_KEYWORDS.some((k) => text.includes(k)) ? "haute" : "normale";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData } = await supabase.auth.getUser(jwt);
    const { data: admin } = userData?.user?.id
      ? await supabase.from("admin_users").select("id").eq("auth_user_id", userData.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!admin) {
      return new Response(JSON.stringify({ error: "Réservé aux comptes admin." }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { ticket_id } = await req.json();
    if (!ticket_id || typeof ticket_id !== "string") {
      return new Response(JSON.stringify({ error: "ticket_id manquant." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: ticket } = await supabase
      .from("support_tickets").select("id,category,subject,description").eq("id", ticket_id).maybeSingle();
    if (!ticket) {
      return new Response(JSON.stringify({ error: `Ticket introuvable : ${ticket_id}` }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        ticket_id,
        category: ticket.category,
        priority: detectPriority(ticket.subject, ticket.description),
        routing_target: ROUTING_BY_CATEGORY[ticket.category] ?? "equipe_support_generale",
        suggested_response: null,
        required_context: [],
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("AI Support Triage Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message ?? String(error) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
