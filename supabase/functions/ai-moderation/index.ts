import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// CF-004 : contrat de sortie minimal §4 du cahier des charges Agents IA — additif uniquement.
const AGENT_VERSION = "1.0.0";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  try {
    const { post_id, content, image_url } = await req.json();

    if (!content && !image_url) {
      return new Response(
        JSON.stringify({ error: "Paramètres manquants : content ou image_url requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Analyse locale par expressions régulières (filtre immédiat)
    const academicToxicPatterns = [
      /\b(triche|fraude|corrige\s*fuite|sujet\s*en\s*avance)\b/i,
      /\b(insulte|haine|arnaque|vente\s*drogue|porn)\b/i,
    ];

    let isViolating = false;
    let violationReason = "";

    for (const pattern of academicToxicPatterns) {
      if (content && pattern.test(content)) {
        isViolating = true;
        violationReason = "Contenu contraire au règlement académique (triche ou propos inappropriés)";
        break;
      }
    }

    // 2. Modération approfondie par Gemini Flash si API Key disponible
    if (!isViolating && GEMINI_API_KEY && content) {
      try {
        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [
                {
                  role: "user",
                  parts: [
                    {
                      text: `Analyse ce message publié sur un forum éducatif scolaire et détermine s'il viole les règles (insultes, harcèlement, triche aux examens officiels, contenus illicites).
Réponds au format JSON strict : {"isViolating": boolean, "reason": string}.
Message : "${content}"`,
                    },
                  ],
                },
              ],
              generationConfig: { responseMimeType: "application/json" },
            }),
          }
        );

        if (geminiRes.ok) {
          const geminiData = await geminiRes.json();
          const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          const parsed = JSON.parse(rawText);
          if (parsed.isViolating) {
            isViolating = true;
            violationReason = parsed.reason || "Contenu jugé inapproprié par l'IA de modération";
          }
        }
      } catch (err) {
        console.warn("Erreur appel Gemini Moderation:", err);
      }
    }

    // 3. Masquage automatique préalable dans forum_posts si infraction détectée (Partie 5 du CDC,
    // règle 5.8 : un score de risque élevé masque immédiatement le message en attendant une revue
    // humaine — colonnes réelles du schéma : flagged / flag_reason / moderation_status).
    if (isViolating && post_id) {
      await supabase
        .from("forum_posts")
        .update({
          flagged: true,
          flag_reason: violationReason,
          moderation_status: "masque",
        })
        .eq("id", post_id);
    }

    const durationMs = Date.now() - startTime;
    console.log(`Modération IA terminée en ${durationMs}ms — violation=${isViolating}`);

    // 4. Traçabilité dans ai_agent_calls (colonnes réelles du schéma)
    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: "moderation",
        provider: GEMINI_API_KEY ? "gemini" : "local_regex",
        model: GEMINI_API_KEY ? "gemini-1.5-flash" : "local_regex",
        tokens_used: Math.ceil((content ?? "").length / 4),
        cost_estimate: GEMINI_API_KEY ? 0.0002 : 0,
        duration_ms: durationMs,
        status: "success",
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(
      JSON.stringify({
        approved: !isViolating,
        flagged: isViolating,
        reason: violationReason,
        _request_id: requestId,
        _agent_version: AGENT_VERSION,
        _duration_ms: durationMs,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Erreur AI Moderation:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
