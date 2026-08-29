// IA-005 "Model Router" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §5) : génération de texte
// générique par CAPABILITY, pas par fournisseur choisi à la main par l'appelant — « Les agents ne
// choisissent pas directement un fournisseur. Ils demandent une capability [...] Le Model Router
// choisit le moteur autorisé. » (§5). Cette fonction EST le point d'entrée réel de ce choix ; le
// Model Router côté Gateway (gateway/app/model_router/) l'appelle plutôt que d'appeler Gemini/Claude
// directement, pour que GEMINI_API_KEY/ANTHROPIC_API_KEY restent uniquement ici.
//
// Politique de routage par capability (reprend celle déjà en place dans ai-course-structuring/
// ai-exercise-generation/ai-catalog-types-generation — Claude préféré + repli Gemini pour la
// qualité pédagogique — plutôt que de la réinventer) :
//   reasoning_strong  -> Claude Sonnet, repli Gemini
//   pedagogy_small     -> Gemini uniquement (capability "légère", pas de recours au provider payant)
//   classification_small -> Gemini uniquement (haut volume, coût prioritaire — §16.3 du cahier maître)
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AGENT_VERSION = "1.0.0";
const VALID_CAPABILITIES = ["reasoning_strong", "pedagogy_small", "classification_small"] as const;
type Capability = (typeof VALID_CAPABILITIES)[number];

async function callClaude(systemPrompt: string, userPrompt: string, maxTokens: number) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-3-5-sonnet-20241022",
      max_tokens: maxTokens,
      system: systemPrompt,
      messages: [{ role: "user", content: userPrompt }],
    }),
  });
  if (!res.ok) throw new Error(`Claude HTTP ${res.status}`);
  const data = await res.json();
  const text = data.content?.[0]?.text ?? "";
  const tokensUsed = (data.usage?.input_tokens ?? 0) + (data.usage?.output_tokens ?? 0);
  return { text, provider: "anthropic", model: "claude-3-5-sonnet-20241022", tokensUsed, costEstimate: tokensUsed * 0.000003 };
}

async function callGemini(systemPrompt: string, userPrompt: string, maxTokens: number) {
  // gemini-3.6-flash consomme des jetons de "réflexion" internes avant la réponse visible (déjà
  // documenté dans ai-tutor-chat/index.ts : ~140 jetons pour "OK") — un budget trop bas (ex: 200)
  // tronque la réponse visible au profit de cette réflexion cachée, observé réellement en testant
  // ce routeur (réponse coupée en plein milieu de phrase). Plancher relevé en conséquence.
  const effectiveMaxTokens = Math.max(maxTokens, 1024);
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
        generationConfig: { maxOutputTokens: effectiveMaxTokens },
      }),
    }
  );
  if (!res.ok) throw new Error(`Gemini HTTP ${res.status}`);
  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  const tokensUsed = data.usageMetadata?.totalTokenCount ?? 0;
  return { text, provider: "gemini", model: "gemini-3.6-flash", tokensUsed, costEstimate: 0 };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  try {
    const { capability, system_prompt, user_prompt, max_tokens } = await req.json();

    if (!VALID_CAPABILITIES.includes(capability)) {
      return new Response(
        JSON.stringify({ error: `capability invalide : '${capability}' (attendu : ${VALID_CAPABILITIES.join(", ")}).` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!user_prompt || typeof user_prompt !== "string") {
      return new Response(
        JSON.stringify({ error: "Paramètre manquant : user_prompt requis." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const cap: Capability = capability;
    const systemPrompt = typeof system_prompt === "string" ? system_prompt : "Tu es un assistant pédagogique utile et concis.";
    const maxTokens = Math.min(Math.max(Number(max_tokens) || 1024, 64), 4096);

    let outcome: { text: string; provider: string; model: string; tokensUsed: number; costEstimate: number } | null = null;
    let lastError: string | null = null;

    // reasoning_strong : Claude préféré (qualité), repli Gemini si absent/en échec.
    if (cap === "reasoning_strong" && ANTHROPIC_API_KEY) {
      try {
        outcome = await callClaude(systemPrompt, user_prompt, maxTokens);
      } catch (err) {
        lastError = String(err);
        console.warn("Claude error, repli Gemini:", err);
      }
    }

    if (!outcome && GEMINI_API_KEY) {
      try {
        outcome = await callGemini(systemPrompt, user_prompt, maxTokens);
      } catch (err) {
        lastError = String(err);
      }
    }

    const durationMs = Date.now() - startTime;

    if (!outcome) {
      const errorMessage = `Échec de génération pour capability='${cap}' : ${lastError ?? "aucun fournisseur disponible"}.`;
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId, agent_type: `model_router:${cap}`, provider: "none",
        duration_ms: durationMs, status: "failed", error_message: errorMessage,
      });
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabase.from("ai_agent_calls").insert({
      request_id: requestId, agent_type: `model_router:${cap}`, provider: outcome.provider, model: outcome.model,
      tokens_used: outcome.tokensUsed, cost_estimate: outcome.costEstimate, duration_ms: durationMs, status: "success",
    });

    return new Response(
      JSON.stringify({
        text: outcome.text,
        _request_id: requestId, _agent_version: AGENT_VERSION, _model: outcome.model,
        _provider: outcome.provider, _duration_ms: durationMs,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("AI Generate Text Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
