// IA-008 — DocumentStructuringAgent (AIA-AGT-016, docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7).
//
// Différence volontaire avec ai-course-structuring (agent "course_structuring", registre IA-001) :
// celui-ci GÉNÈRE un cours à partir de notes brèves (créatif), celui-ci STRUCTURE une source déjà
// importée (raw_source_text — le texte intégral d'un document réel) sans inventer de contenu
// pédagogique nouveau. Chaque bloc produit porte un `source_excerpt` (extrait littéral de la source
// dont il provient) pour la traçabilité exigée par le cahier (« Conserve la traçabilité source —
// bloc »). Cet agent NE PUBLIE JAMAIS (règle explicite du cahier) : il retourne des blocs candidats
// que l'admin doit relire dans lessons_manager_screen.dart avant tout enregistrement.
//
// OCR différé (voir docs/CONTENT_FACTORY_GAP_ANALYSIS.md, IA-008) : cette version ne prend en entrée
// que du texte déjà extrait (raw_source_text) — pas d'image/PDF scanné, qui nécessiterait
// OCRAgent (AIA-AGT-014, OpenCV/PaddleOCR) en amont, explicitement différé faute d'infra.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AGENT_VERSION = "1.0.0";
const MODEL = "gemini-3.6-flash";
const VALID_BLOCK_TYPES = [
  "paragraph",
  "definition",
  "theoreme",
  "formule",
  "methode",
  "exemple",
  "piege",
  "conseil_examen",
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  const logResult = async (
    status: "success" | "failed",
    extra: Record<string, unknown>,
  ) => {
    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: "document_structuring",
        provider: status === "success" ? "gemini" : "none",
        duration_ms: Date.now() - startTime,
        status,
        ...extra,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }
  };

  try {
    const { raw_source_text, subject_name } = await req.json();

    if (
      !raw_source_text || typeof raw_source_text !== "string" ||
      raw_source_text.trim().length < 20
    ) {
      return new Response(
        JSON.stringify({
          error:
            "raw_source_text manquant ou trop court (document réellement importé attendu, pas de simples notes).",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!GEMINI_API_KEY) {
      const errorMessage =
        "DocumentStructuringAgent n'est pas configuré (clé Gemini absente côté serveur).";
      await logResult("failed", { error_message: errorMessage });
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Règle stricte : SEGMENTER, jamais GÉNÉRER. Chaque bloc doit être traçable à un extrait littéral
    // de la source (source_excerpt) — un bloc sans extrait correspondant dans le texte source est un
    // signal d'hallucination à traiter comme une ambiguïté, pas comme un résultat silencieusement
    // accepté.
    const systemPrompt =
      `Tu es un outil de STRUCTURATION de document, pas un générateur de contenu.
On te donne le texte intégral d'un document pédagogique déjà existant${
        subject_name ? ` (matière : ${subject_name})` : ""
      }.
Ta seule tâche : découper ce texte en blocs typés, SANS RIEN INVENTER ni reformuler le fond.

Règles strictes :
- Chaque bloc doit correspondre à un passage réel du texte source — jamais un fait ou une explication qui n'y figure pas.
- "source_excerpt" doit être un extrait LITTÉRAL (copié-collé, pas paraphrasé) du texte source dont le bloc est dérivé.
- Type de bloc parmi : ${VALID_BLOCK_TYPES.join(", ")}.
- Si une partie du texte est ambiguë (illisible, hors sujet, structure peu claire), liste-la dans "ambiguities" au lieu de forcer un bloc.
- "confidence" globale entre 0 et 1 : ta confiance que le découpage reflète fidèlement la source, sans invention.
- Ne renvoie QUE du JSON valide, sans texte additionnel.

Format de sortie exact :
{
  "blocks": [{"type": "definition", "heading": "...", "body": "reformulation fidèle et concise", "source_excerpt": "extrait littéral de la source", "formulas": []}],
  "ambiguities": ["description d'un passage non structuré et pourquoi"],
  "confidence": 0.0
}`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            role: "user",
            parts: [{
              text: `${systemPrompt}\n\nTexte source à structurer :\n${
                raw_source_text.slice(0, 20000)
              }`,
            }],
          }],
          generationConfig: {
            responseMimeType: "application/json",
            maxOutputTokens: 8192,
          },
        }),
      },
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error("Gemini API error:", geminiRes.status, errText);
      const errorMessage =
        "DocumentStructuringAgent est momentanément indisponible (quota atteint ou erreur du fournisseur).";
      await logResult("failed", { error_message: errorMessage });
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const geminiData = await geminiRes.json();
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    let structured: {
      blocks?: unknown[];
      ambiguities?: string[];
      confidence?: number;
    };
    try {
      structured = JSON.parse(rawText);
    } catch (parseErr) {
      const errorMessage = `Réponse non-JSON du modèle : ${
        (parseErr as Error).message
      }`;
      await logResult("failed", { error_message: errorMessage });
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Traçabilité (règle du cahier) : un bloc sans source_excerpt correspondant réellement présent
    // dans le texte source est rétrogradé en ambiguïté plutôt que silencieusement accepté — vérif
    // mécanique simple (sous-chaîne), pas une preuve sémantique complète, mais un vrai garde-fou.
    const blocks = Array.isArray(structured.blocks) ? structured.blocks : [];
    const ambiguities = Array.isArray(structured.ambiguities)
      ? [...structured.ambiguities]
      : [];
    const verifiedBlocks = [];
    for (const b of blocks as Record<string, unknown>[]) {
      const excerpt = typeof b.source_excerpt === "string"
        ? b.source_excerpt.trim()
        : "";
      const traceable = excerpt.length > 0 &&
        raw_source_text.includes(
          excerpt.slice(0, Math.min(excerpt.length, 40)),
        );
      if (!traceable) {
        ambiguities.push(
          `Bloc "${
            b.heading ?? b.type ?? "?"
          }" écarté : source_excerpt introuvable tel quel dans le texte source (risque d'invention).`,
        );
        continue;
      }
      verifiedBlocks.push(b);
    }

    const tokensUsed = geminiData.usageMetadata?.totalTokenCount ?? 0;
    const durationMs = Date.now() - startTime;
    await logResult("success", {
      model: MODEL,
      tokens_used: tokensUsed,
      cost_estimate: 0,
    });

    return new Response(
      JSON.stringify({
        blocks: verifiedBlocks,
        ambiguities,
        confidence: typeof structured.confidence === "number"
          ? structured.confidence
          : 0,
        _request_id: requestId,
        _agent_version: AGENT_VERSION,
        _model: MODEL,
        _duration_ms: durationMs,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("AI Document Structuring Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
