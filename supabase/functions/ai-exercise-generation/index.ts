import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
// Mode mock explicite (voir 06_ai_pipeline.md) : absent par défaut, jamais un comportement silencieux.
const AI_MOCK_MODE = Deno.env.get("AI_MOCK_MODE") === "true";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Contenu utilisé UNIQUEMENT quand AI_MOCK_MODE=true — jamais comme repli silencieux en cas
// d'échec des appels API réels (voir 06_ai_pipeline.md).
function buildMockExercises(count: number, format: string, difficulty: string): Record<string, unknown>[] {
  return Array.from({ length: count }, (_, i) => ({
    title: `Exercice ${i + 1} (MOCK, ${difficulty})`,
    statement: `Énoncé généré factice n°${i + 1} — remplacez par un contenu réel avant publication.`,
    correction: format === "qcm"
      ? "Réponse correcte : Option B — justification factice."
      : "Corrigé détaillé factice, étape par étape.",
    options: format === "qcm" ? ["Option A", "Option B", "Option C", "Option D"] : null,
    correct_index: format === "qcm" ? 1 : null,
  }));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const {
      subject_id,
      chapter_id,
      type,
      difficulty,
      format,
      count,
      raw_notes,
      prompt_directives,
    } = await req.json();

    const exerciseCount = Math.min(Math.max(Number(count) || 5, 1), 20);

    if (!subject_id && !chapter_id && !raw_notes) {
      return new Response(
        JSON.stringify({ error: "Paramètres manquants : subject_id, chapter_id ou raw_notes requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Récupération du catalogue pédagogique de la matière (Section 16.0 du CDC)
    let catalogPrompt = "Structure type : énoncé clair, corrigé pas à pas, niveau calibré.";
    if (subject_id) {
      const { data: catalogItems } = await supabase
        .from("content_catalog")
        .select("element_type, description")
        .eq("subject_id", subject_id);

      if (catalogItems && catalogItems.length > 0) {
        catalogPrompt = catalogItems
          .map((item: { element_type: string; description?: string }) =>
            `- ${item.element_type}: ${item.description ?? ""}`
          )
          .join("\n");
      }
    }

    const systemPrompt = `Tu es un expert pédagogique national et concepteur d'exercices scolaires d'excellence.
Ta mission est de générer ${exerciseCount} exercice(s) de type "${type ?? "entraînement"}", format "${format ?? "qcm"}", niveau de difficulté "${difficulty ?? "facile"}", au format JSON strict.

Typologie pédagogique de référence :
${catalogPrompt}

Règles strictes :
- Toutes les formules mathématiques, chimiques ou physiques DOIVENT être encadrées par des balises LaTeX : $...$ pour inline ou $$...$$ pour blocs séparés.
- Le corrigé doit être pas-à-pas, justifié, rigoureux.
- Si le format est "qcm", fournir exactement 4 options et l'index (0-3) de la bonne réponse.
- Ne renvoyer QUE du JSON valide, sans texte additionnel ni balises de commentaires Markdown.`;

    const userPrompt = `Contexte / notes brutes :
${raw_notes ?? "Génère des exercices conformes au programme officiel du chapitre sélectionné."}

${prompt_directives ? `Directives spécifiques du professeur : ${prompt_directives}` : ""}

Génère un tableau JSON exact de ${exerciseCount} exercice(s) avec les clés :
[
  {
    "title": "Titre court de l'exercice",
    "statement": "Énoncé complet avec LaTeX si nécessaire",
    "correction": "Corrigé pas-à-pas détaillé",
    "options": ["Option A", "Option B", "Option C", "Option D"] ou null si non-QCM,
    "correct_index": 0 à 3, ou null si non-QCM
  }
]`;

    let exercises: Record<string, unknown>[] | null = null;
    let provider = "none";
    let tokensUsed = 0;
    let costEstimate = 0;

    if (AI_MOCK_MODE) {
      exercises = buildMockExercises(exerciseCount, format ?? "qcm", difficulty ?? "facile");
      provider = "mock";
    } else {
      if (ANTHROPIC_API_KEY) {
        try {
          const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
              "x-api-key": ANTHROPIC_API_KEY,
              "anthropic-version": "2023-06-01",
              "content-type": "application/json",
            },
            body: JSON.stringify({
              model: "claude-3-5-sonnet-20241022",
              max_tokens: 4000,
              system: systemPrompt,
              messages: [{ role: "user", content: userPrompt }],
            }),
          });

          if (anthropicRes.ok) {
            const anthropicData = await anthropicRes.json();
            const rawText = anthropicData.content?.[0]?.text ?? "";
            const cleanedJson = rawText.replace(/^```json\s*/i, "").replace(/\s*```$/i, "").trim();
            exercises = JSON.parse(cleanedJson);
            provider = "anthropic";
            tokensUsed = (anthropicData.usage?.input_tokens ?? 0) + (anthropicData.usage?.output_tokens ?? 0);
            costEstimate = tokensUsed * 0.000003;
          }
        } catch (anthropicErr) {
          console.warn("Anthropic API Error:", anthropicErr);
        }
      }

      if (!exercises && GEMINI_API_KEY) {
        try {
          const geminiRes = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [{ role: "user", parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }] }],
                generationConfig: { responseMimeType: "application/json" },
              }),
            }
          );

          if (geminiRes.ok) {
            const geminiData = await geminiRes.json();
            const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
            exercises = JSON.parse(rawText);
            provider = "gemini";
            tokensUsed = geminiData.usageMetadata?.totalTokenCount ?? 0;
            costEstimate = tokensUsed * 0.00000035;
          }
        } catch (geminiErr) {
          console.warn("Gemini API Error:", geminiErr);
        }
      }
    }

    const durationMs = Date.now() - startTime;
    console.log(`Génération d'exercices IA terminée en ${durationMs}ms via provider=${provider}`);

    // Aucun résultat réel et mode mock inactif : erreur explicite, jamais de contenu statique
    // déguisé en résultat réel (voir 06_ai_pipeline.md).
    if (!exercises) {
      return new Response(
        JSON.stringify({
          error: "Échec de la génération IA : aucun fournisseur (Claude, Gemini) n'a retourné de résultat exploitable.",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      await supabase.from("ai_agent_calls").insert({
        agent_type: "exercise_generation",
        provider,
        tokens_used: tokensUsed,
        cost_estimate: costEstimate,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(JSON.stringify({ exercises, _mock: provider === "mock" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("AI Exercise Generation Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
