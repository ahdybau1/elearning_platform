import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";



const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

// Section 6.4 du CDC : Automatisation des rappels de fin d'abonnement (J-3, J-1, Jour J)
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const now = new Date();
    const todayStr = now.toISOString().split("T")[0];

    // 1. Récupération des abonnements expirant dans 3 jours (J-3), 1 jour (J-1) ou aujourd'hui
    // (Jour J) — table et colonnes réelles du schéma : `subscriptions` (statut 'actif', pas
    // 'active'), pas de colonne auto_renew (voir 02_migration_discipline.md, règle 4).
    const { data: expiringSubs, error: subsError } = await supabase
      .from("subscriptions")
      .select("id, profile_id, tier_id, end_date")
      .eq("status", "actif")
      .gte("end_date", todayStr);

    if (subsError) throw subsError;

    let processedCount = 0;

    for (const sub of expiringSubs ?? []) {
      const endDate = new Date(sub.end_date);
      const diffTime = endDate.getTime() - now.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      // Alignés sur les event_key déjà seedés dans notification_templates pour qu'un futur envoi
      // de notification puisse joindre le bon template.
      let reminderType = "";
      if (diffDays === 3) reminderType = "j3_expiration";
      else if (diffDays === 1) reminderType = "j1_expiration";
      else if (diffDays === 0) reminderType = "jour_j_expiration";

      if (reminderType) {
        // scheduled_reminders est clé par profile_id (pas subscription_id — voir le schéma réel).
        const { data: existing } = await supabase
          .from("scheduled_reminders")
          .select("id")
          .eq("profile_id", sub.profile_id)
          .eq("reminder_type", reminderType)
          .maybeSingle();

        if (!existing) {
          await supabase.from("scheduled_reminders").insert({
            profile_id: sub.profile_id,
            reminder_type: reminderType,
            trigger_date: now.toISOString(),
            sent: true,
          });
          processedCount++;
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        checked_subscriptions: expiringSubs?.length ?? 0,
        reminders_sent: processedCount,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Cron Subscription Reminders Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
