// IA-004 partie 2 (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §10) : génère de vrais embeddings via
// Gemini text-embedding-004, pour que la Gateway (gateway/app/rag/) puisse peupler ai_rag_chunks
// sans dupliquer GEMINI_API_KEY dans un second endroit (gateway/.env) — le secret reste UNIQUEMENT
// ici, comme les autres clés IA du projet (voir mémoire projet : jamais reloggé/réexposé).
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

const AGENT_VERSION = "1.0.0";
// text-embedding-004 n'existe plus (confirmé via /v1beta/models le 2026-08-29 : 404). Modèles
// réellement disponibles à cette date : gemini-embedding-001 (stable), gemini-embedding-2(-preview).
// Choisi le stable. Aucun ne supporte batchEmbedContents (absent de supportedGenerationMethods) —
// seulement embedContent (un texte à la fois, appelé ici en parallèle) et asyncBatchEmbedContent
// (protocole de long-running-operation plus complexe, pas nécessaire pour ce volume).
const MODEL = "gemini-embedding-001";
const EMBEDDING_DIM = 768; // doit rester synchronisé avec vector(768) — migration 56 (Matryoshka :
// gemini-embedding-001 produit nativement 3072 dims, réduit via outputDimensionality)

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  try {
    const { texts } = await req.json();

    if (!Array.isArray(texts) || texts.length === 0) {
      return new Response(
        JSON.stringify({ error: "Paramètre manquant : texts (tableau de chaînes non vide) requis." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (texts.length > 100) {
      return new Response(
        JSON.stringify({ error: "Trop de textes en un seul appel (max 100)." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!GEMINI_API_KEY) {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId, agent_type: "embeddings_generation", provider: "gemini",
        duration_ms: Date.now() - startTime, status: "failed",
        error_message: "GEMINI_API_KEY absente côté serveur.",
      });
      return new Response(
        JSON.stringify({ error: "Génération d'embeddings indisponible (clé absente).", _request_id: requestId }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // embedContent un par un, en parallèle (pas de batchEmbedContents disponible pour ce modèle —
    // voir commentaire sur MODEL). Promise.all : une seule requête en échec fait échouer l'appel
    // entier plutôt que de renvoyer un lot partiel silencieusement incomplet.
    let embeddings: number[][];
    let providerErrorStatus: number | null = null;
    let providerErrorText = "";
    try {
      embeddings = await Promise.all(
        texts.map(async (t: string) => {
          const res = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:embedContent?key=${GEMINI_API_KEY}`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                content: { parts: [{ text: t }] },
                outputDimensionality: EMBEDDING_DIM,
              }),
            }
          );
          if (!res.ok) {
            providerErrorStatus = res.status;
            providerErrorText = await res.text();
            throw new Error(`Gemini HTTP ${res.status}`);
          }
          const data = await res.json();
          return data.embedding.values as number[];
        })
      );
    } catch (_err) {
      const durationMs = Date.now() - startTime;
      console.error("Gemini embeddings error:", providerErrorStatus, providerErrorText);
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId, agent_type: "embeddings_generation", provider: "gemini", model: MODEL,
        duration_ms: durationMs, status: "failed",
        error_message: `Gemini HTTP ${providerErrorStatus} : ${providerErrorText.slice(0, 300)}`,
      });
      return new Response(
        JSON.stringify({ error: "Échec de la génération d'embeddings (fournisseur).", _request_id: requestId }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const durationMs = Date.now() - startTime;

    if (embeddings.length !== texts.length || embeddings.some((e) => e.length !== EMBEDDING_DIM)) {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId, agent_type: "embeddings_generation", provider: "gemini", model: MODEL,
        duration_ms: durationMs, status: "failed",
        error_message: `Réponse inattendue : ${embeddings.length} embedding(s) pour ${texts.length} texte(s).`,
      });
      return new Response(
        JSON.stringify({ error: "Réponse du fournisseur d'embeddings incohérente.", _request_id: requestId }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabase.from("ai_agent_calls").insert({
      request_id: requestId, agent_type: "embeddings_generation", provider: "gemini", model: MODEL,
      tokens_used: 0, cost_estimate: 0, duration_ms: durationMs, status: "success",
    });

    return new Response(
      JSON.stringify({
        embeddings, _request_id: requestId, _agent_version: AGENT_VERSION, _model: MODEL, _duration_ms: durationMs,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("AI Embeddings Generation Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
