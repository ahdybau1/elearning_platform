// IA-005 "Model Router" — routage par CAPABILITY, multi-fournisseurs GRATUITS avec bascule
// automatique (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §5 ; docs/CAHIER_TECHNIQUE_FRAMEWORKS_OUTILS_IA.md
// §4 ; PROVIDER_LOCK_IN=false). « Les agents ne choisissent pas un fournisseur : ils demandent une
// capability, le Model Router choisit le moteur autorisé disponible. »
//
// Contrainte projet : aucune API IA payante obligatoire. Chaque adaptateur n'est actif que si son
// function-secret est présent. À l'épuisement du quota (HTTP 429) ou à une panne d'un fournisseur,
// le routeur bascule automatiquement sur le suivant de la chaîne. Un free tier externe n'est jamais
// une garantie de production — les fonctions critiques ont un repli déterministe/validé en amont.
//
// Fournisseurs gratuits supportés (adaptateurs OpenAI-compatibles + Gemini) :
//   GEMINI_API_KEY      → Google Gemini            (gemini-3.6-flash)
//   GROQ_API_KEY        → Groq                     (llama-3.3-70b-versatile / llama-3.1-8b-instant)
//   OPENROUTER_API_KEY  → OpenRouter (modèles :free)(meta-llama/llama-3.3-70b-instruct:free …)
//   CEREBRAS_API_KEY    → Cerebras                 (llama-3.3-70b)
//   MISTRAL_API_KEY     → Mistral La Plateforme    (mistral-small-latest)
//   HF_API_KEY          → HuggingFace Inference    (repli léger)
// Chaque nom de modèle est surchargeable par un secret <PROVIDER>_MODEL_<CAP>.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const AGENT_VERSION = "2.0.0";

const CAPS = ["reasoning_strong", "pedagogy_small", "classification_small", "structuring_json"] as const;
type Capability = (typeof CAPS)[number];

interface GenResult {
  text: string;
  provider: string;
  model: string;
  tokensUsed: number;
}
interface GenOpts {
  system: string;
  user: string;
  maxTokens: number;
  json: boolean;
  temperature: number;
}
type Reason = "ok" | "not_configured" | "quota" | "auth" | "server" | "empty" | "timeout" | "error";

function env(k: string): string {
  return Deno.env.get(k) ?? "";
}
function modelFor(provider: string, cap: Capability, def: string): string {
  return env(`${provider.toUpperCase()}_MODEL_${cap.toUpperCase()}`) || def;
}
function classify(status: number): Reason {
  if (status === 429) return "quota";
  if (status === 401 || status === 403) return "auth";
  if (status >= 500) return "server";
  return "error";
}

// ─── Adaptateur OpenAI-compatible (Groq / OpenRouter / Cerebras / Mistral) ───
async function callOpenAICompat(
  base: string,
  key: string,
  model: string,
  o: GenOpts,
  extraHeaders: Record<string, string> = {},
): Promise<GenResult> {
  const res = await fetch(`${base}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${key}`,
      ...extraHeaders,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: o.system },
        { role: "user", content: o.user },
      ],
      max_tokens: o.maxTokens,
      temperature: o.temperature,
      ...(o.json ? { response_format: { type: "json_object" } } : {}),
    }),
    signal: AbortSignal.timeout(90_000),
  });
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status}`);
    (err as { reason?: Reason }).reason = classify(res.status);
    (err as { detail?: string }).detail = (await res.text()).slice(0, 200);
    throw err;
  }
  const data = await res.json();
  const text = (data.choices?.[0]?.message?.content ?? "").trim();
  if (!text) {
    const err = new Error("réponse vide");
    (err as { reason?: Reason }).reason = "empty";
    throw err;
  }
  return { text, provider: base, model, tokensUsed: data.usage?.total_tokens ?? 0 };
}

// ─── Adaptateur Gemini ───
async function callGemini(key: string, model: string, o: GenOpts): Promise<GenResult> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: o.system }] },
        contents: [{ role: "user", parts: [{ text: o.user }] }],
        generationConfig: {
          // gemini-3.6-flash consomme des jetons de réflexion cachés ; plancher relevé.
          maxOutputTokens: Math.max(o.maxTokens, 2048),
          temperature: o.temperature,
          ...(o.json ? { responseMimeType: "application/json" } : {}),
        },
      }),
      signal: AbortSignal.timeout(90_000),
    },
  );
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status}`);
    (err as { reason?: Reason }).reason = classify(res.status);
    (err as { detail?: string }).detail = (await res.text()).slice(0, 200);
    throw err;
  }
  const data = await res.json();
  const cand = data.candidates?.[0];
  const text = (cand?.content?.parts ?? [])
    .map((p: { text?: string }) => p?.text ?? "")
    .join("")
    .trim();
  if (!text) {
    const err = new Error(`réponse vide (finishReason=${cand?.finishReason ?? "?"})`);
    (err as { reason?: Reason }).reason = "empty";
    throw err;
  }
  return { text, provider: "gemini", model, tokensUsed: data.usageMetadata?.totalTokenCount ?? 0 };
}

// ─── Chaîne de fournisseurs par capability ───
type Attempt = () => Promise<GenResult>;

function buildChain(cap: Capability, o: GenOpts): { provider: string; run: Attempt }[] {
  const chain: { provider: string; run: Attempt }[] = [];
  const strong = cap === "reasoning_strong" || cap === "structuring_json";

  // Ordre : les moteurs 70B gratuits d'abord pour les tâches fortes, puis Gemini, puis petits.
  if (env("GROQ_API_KEY")) {
    const m = modelFor("groq", cap, strong ? "llama-3.3-70b-versatile" : "llama-3.1-8b-instant");
    chain.push({ provider: "groq", run: () => callOpenAICompat("https://api.groq.com/openai/v1", env("GROQ_API_KEY"), m, o) });
  }
  if (env("CEREBRAS_API_KEY")) {
    const m = modelFor("cerebras", cap, strong ? "llama-3.3-70b" : "llama-3.1-8b");
    chain.push({ provider: "cerebras", run: () => callOpenAICompat("https://api.cerebras.ai/v1", env("CEREBRAS_API_KEY"), m, o) });
  }
  if (env("GEMINI_API_KEY")) {
    const m = modelFor("gemini", cap, "gemini-3.6-flash");
    chain.push({ provider: "gemini", run: () => callGemini(env("GEMINI_API_KEY"), m, o) });
  }
  if (env("OPENROUTER_API_KEY")) {
    const m = modelFor("openrouter", cap, strong
      ? "meta-llama/llama-3.3-70b-instruct:free"
      : "google/gemma-2-9b-it:free");
    chain.push({
      provider: "openrouter",
      run: () => callOpenAICompat("https://openrouter.ai/api/v1", env("OPENROUTER_API_KEY"), m, o, {
        "HTTP-Referer": "https://pq-learn.app",
        "X-Title": "pq learn",
      }),
    });
  }
  if (env("MISTRAL_API_KEY")) {
    const m = modelFor("mistral", cap, "mistral-small-latest");
    chain.push({ provider: "mistral", run: () => callOpenAICompat("https://api.mistral.ai/v1", env("MISTRAL_API_KEY"), m, o) });
  }
  return chain;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  try {
    const body = await req.json();
    const capability: string = body.capability;
    const system = typeof body.system_prompt === "string" ? body.system_prompt : "Tu es un assistant pédagogique utile et concis.";
    const user = body.user_prompt;
    const json = body.json === true;
    const maxTokens = Math.min(Math.max(Number(body.max_tokens) || 2048, 64), 32_768);
    const temperature = typeof body.temperature === "number" ? body.temperature : 0.4;

    if (!CAPS.includes(capability as Capability)) {
      return new Response(JSON.stringify({ error: `capability invalide : '${capability}' (attendu : ${CAPS.join(", ")}).` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    if (!user || typeof user !== "string") {
      return new Response(JSON.stringify({ error: "Paramètre manquant : user_prompt requis." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const cap = capability as Capability;
    const opts: GenOpts = { system, user, maxTokens, json, temperature };
    const chain = buildChain(cap, opts);
    const attemptLog: { provider: string; ok: boolean; reason: Reason; detail?: string }[] = [];

    if (chain.length === 0) {
      const msg = "Aucun fournisseur IA gratuit configuré (GEMINI_API_KEY, GROQ_API_KEY, OPENROUTER_API_KEY, CEREBRAS_API_KEY, MISTRAL_API_KEY).";
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId, agent_type: `model_router:${cap}`, provider: "none",
        duration_ms: Date.now() - startTime, status: "failed", error_message: msg,
      });
      return new Response(JSON.stringify({ error: msg, _request_id: requestId, provider_chain: [] }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    let outcome: GenResult | null = null;
    for (const step of chain) {
      try {
        outcome = await step.run();
        attemptLog.push({ provider: step.provider, ok: true, reason: "ok" });
        break;
      } catch (e) {
        const reason = ((e as { reason?: Reason }).reason ?? "error") as Reason;
        attemptLog.push({
          provider: step.provider, ok: false, reason,
          detail: (e as { detail?: string }).detail ?? (e as Error).message,
        });
        // 429/panne → on bascule ; 'auth' aussi (clé invalide) — inutile d'insister.
        continue;
      }
    }

    const durationMs = Date.now() - startTime;

    if (!outcome) {
      const msg = `Tous les fournisseurs ont échoué pour capability='${cap}' : ` +
        attemptLog.map((a) => `${a.provider}=${a.reason}`).join(", ");
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId, agent_type: `model_router:${cap}`, provider: "none",
        duration_ms: durationMs, status: "failed", error_message: msg,
      });
      return new Response(JSON.stringify({ error: msg, _request_id: requestId, provider_chain: attemptLog }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    await supabase.from("ai_agent_calls").insert({
      request_id: requestId, agent_type: `model_router:${cap}`, provider: outcome.provider, model: outcome.model,
      tokens_used: outcome.tokensUsed, cost_estimate: 0, duration_ms: durationMs, status: "success",
      error_message: attemptLog.length > 1 ? `bascule: ${attemptLog.slice(0, -1).map((a) => `${a.provider}=${a.reason}`).join(", ")}` : null,
    });

    return new Response(JSON.stringify({
      text: outcome.text,
      _request_id: requestId, _agent_version: AGENT_VERSION,
      _model: outcome.model, _provider: outcome.provider, _duration_ms: durationMs,
      provider_chain: attemptLog,
    }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("AI Generate Text (Model Router) Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message ?? String(error), _request_id: requestId }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
