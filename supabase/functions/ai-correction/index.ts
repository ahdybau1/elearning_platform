// CorrectionAgent (AIA-AGT-005, IA-009 — docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7/§22), porté depuis
// gateway/app/agents/correction_agent.py (2026-09-06) : audit du même jour, aucun code Flutter
// n'appelle jamais le Gateway Python (jamais déployé) — cet agent, bien que "actif en production"
// dans le registre, était réellement injoignable. Même logique exacte, réécrite en Deno pour rester
// à coût zéro (Edge Function déjà gratuite/déployée, pas d'hébergement Python payant).
//
// Règle explicite du cahier : « Séparer machine_score, confidence, feedback et official_grade. Une
// note officielle nécessitant validation humaine ne peut être écrite directement. » N'écrit JAMAIS
// official_correct (réservé admin, RLS migration 68) — uniquement les champs ai_*, une proposition.
//
// Ne traite que reponse_courte/redaction — le QCM a déjà une correction déterministe exacte.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AGENT_VERSION = "1.0.0";
const CORRECTABLE_FORMATS = new Set(["reponse_courte", "redaction"]);

function parseLlmJson(text: string): Record<string, unknown> {
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error(`Réponse du modèle non-JSON, aucun bloc {...} trouvé : ${text.slice(0, 200)}`);
    }
    return JSON.parse(match[0]);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  const logResult = async (status: "success" | "failed", errorMessage?: string) => {
    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: "AIA-AGT-005",
        provider: status === "success" ? "gemini" : "none",
        duration_ms: Date.now() - startTime,
        status,
        error_message: errorMessage,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }
  };

  try {
    const { attempt_id } = await req.json();
    if (!attempt_id || typeof attempt_id !== "string") {
      return new Response(JSON.stringify({ error: "attempt_id manquant." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: attempt } = await supabase
      .from("exercise_attempts")
      .select("id,exercise_id,submitted_answer")
      .eq("id", attempt_id)
      .maybeSingle();
    if (!attempt) {
      const msg = `Tentative introuvable : ${attempt_id}`;
      await logResult("failed", msg);
      return new Response(JSON.stringify({ error: msg }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: exercise } = await supabase
      .from("exercises")
      .select("format,instructions_json,solution_json")
      .eq("id", attempt.exercise_id)
      .maybeSingle();
    if (!exercise) {
      const msg = `Exercice introuvable pour la tentative ${attempt_id}.`;
      await logResult("failed", msg);
      return new Response(JSON.stringify({ error: msg }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!CORRECTABLE_FORMATS.has(exercise.format)) {
      const msg = `CorrectionAgent ne traite que reponse_courte/redaction — format='${exercise.format}' a déjà une correction déterministe.`;
      await logResult("failed", msg);
      return new Response(JSON.stringify({ error: msg }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const submittedText = String(attempt.submitted_answer?.text ?? "").trim();
    const statement = String(exercise.instructions_json?.statement ?? "");
    const referenceCorrection = String(exercise.solution_json?.correction ?? "");

    let result: {
      ai_score: number;
      ai_confidence: number;
      ai_feedback: string;
      ai_misconceptions: string[];
      needs_human_review: boolean;
    };

    if (!submittedText) {
      result = {
        ai_score: 0.0, ai_confidence: 1.0, ai_feedback: "Aucune réponse soumise.",
        ai_misconceptions: [], needs_human_review: false,
      };
    } else {
      const prompt = `Énoncé de l'exercice :
${statement}

Corrigé de référence (barème) :
${referenceCorrection}

Réponse soumise par l'élève :
${submittedText}

Évalue cette réponse par rapport au corrigé de référence, comme un correcteur bienveillant mais rigoureux.
Réponds en JSON strict, rien d'autre :
{"score": <0.0 à 1.0>, "confidence": <0.0 à 1.0>, "feedback": "<explication pédagogique brève, en français, orientée élève>", "misconceptions": ["<erreur conceptuelle identifiée, si il y en a>"], "needs_review": <true si la réponse est ambiguë, partiellement correcte de façon non triviale, ou si ta confiance est faible>}`;

      const genRes = await fetch(`${SUPABASE_URL}/functions/v1/ai-generate-text`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "apikey": SUPABASE_SERVICE_ROLE_KEY,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ capability: "pedagogy_small", user_prompt: prompt, max_tokens: 1024 }),
      });
      const genBody = await genRes.json();
      if (!genRes.ok || !genBody.text) {
        const msg = genBody.error ?? "Échec du Model Router (ai-generate-text).";
        await logResult("failed", msg);
        return new Response(JSON.stringify({ error: msg, _request_id: requestId }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const parsed = parseLlmJson(genBody.text);
      result = {
        ai_score: Number(parsed.score ?? 0.0),
        ai_confidence: Number(parsed.confidence ?? 0.0),
        ai_feedback: String(parsed.feedback ?? ""),
        ai_misconceptions: Array.isArray(parsed.misconceptions) ? parsed.misconceptions.map(String) : [],
        // Défaut prudent : à revoir si le champ est absent de la réponse du modèle.
        needs_human_review: parsed.needs_review === undefined ? true : Boolean(parsed.needs_review),
      };
    }

    const { error: updateErr } = await supabase
      .from("exercise_attempts")
      .update(result)
      .eq("id", attempt_id);
    if (updateErr) {
      const msg = `Écriture des champs ai_* échouée : ${updateErr.message}`;
      await logResult("failed", msg);
      return new Response(JSON.stringify({ error: msg }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    await logResult("success");
    return new Response(
      JSON.stringify({
        ...result,
        _request_id: requestId,
        _agent_version: AGENT_VERSION,
        _duration_ms: Date.now() - startTime,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("AI Correction Error:", error);
    await logResult("failed", (error as Error).message ?? String(error));
    return new Response(JSON.stringify({ error: (error as Error).message ?? String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
