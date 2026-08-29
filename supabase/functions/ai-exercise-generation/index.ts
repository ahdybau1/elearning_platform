import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
// Claude retiré le 2026-08-29 (demande explicite du porteur de projet) — voir le commentaire
// équivalent dans ai-course-structuring/index.ts : ANTHROPIC_API_KEY n'a jamais été configurée.
// Mode mock explicite (voir 06_ai_pipeline.md) : absent par défaut, jamais un comportement silencieux.
const AI_MOCK_MODE = Deno.env.get("AI_MOCK_MODE") === "true";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// CF-004 : contrat de sortie minimal §4 du cahier des charges Agents IA — additif uniquement.
const AGENT_VERSION = "1.0.0";

// Contenu utilisé UNIQUEMENT quand AI_MOCK_MODE=true — jamais comme repli silencieux en cas
// d'échec des appels API réels (voir 06_ai_pipeline.md).
function buildMockExercises(
  count: number,
  format: string,
  difficulty: string,
): Record<string, unknown>[] {
  return Array.from({ length: count }, (_, i) => ({
    title: `Exercice ${i + 1} (MOCK, ${difficulty})`,
    statement: `Énoncé généré factice n°${
      i + 1
    } — remplacez par un contenu réel avant publication.`,
    correction: format === "qcm"
      ? "Réponse correcte : Option B — justification factice."
      : "Corrigé détaillé factice, étape par étape.",
    options: format === "qcm"
      ? ["Option A", "Option B", "Option C", "Option D"]
      : null,
    correct_index: format === "qcm" ? 1 : null,
    hints: [
      "Indice factice 1 — relire l'énoncé.",
      "Indice factice 2 — identifier la formule adaptée.",
    ],
    skills: ["Compétence factice"],
  }));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

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
        JSON.stringify({
          error:
            "Paramètres manquants : subject_id, chapter_id ou raw_notes requis",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 1. Récupération du catalogue pédagogique de la matière (Section 16.0 du CDC)
    let catalogPrompt =
      "Structure type : énoncé clair, corrigé pas à pas, niveau calibré.";
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

    const systemPrompt =
      `Tu es un expert pédagogique national et concepteur d'exercices scolaires d'excellence.
Ta mission est de générer ${exerciseCount} exercice(s) de type "${
        type ?? "entraînement"
      }", format "${format ?? "qcm"}", niveau de difficulté "${
        difficulty ?? "facile"
      }", au format JSON strict.

Typologie pédagogique de référence :
${catalogPrompt}

Règles strictes :
- Toutes les formules mathématiques, chimiques ou physiques DOIVENT être encadrées par des balises LaTeX : $...$ pour inline ou $$...$$ pour blocs séparés.
- Le corrigé doit être pas-à-pas, justifié, rigoureux.
- Si le format est "qcm", fournir exactement 4 options et l'index (0-3) de la bonne réponse.
- Fournir 2 à 3 indices progressifs (du plus léger au plus explicite), à utiliser avant de révéler la solution — jamais la réponse finale dans un indice.
- Fournir 1 à 3 compétences courtes (2-5 mots) mobilisées par l'exercice, pour le rattachement pédagogique.
- Ne renvoyer QUE du JSON valide, sans texte additionnel ni balises de commentaires Markdown.`;

    const userPrompt = `Contexte / notes brutes :
${
      raw_notes ??
        "Génère des exercices conformes au programme officiel du chapitre sélectionné."
    }

${
      prompt_directives
        ? `Directives spécifiques du professeur : ${prompt_directives}`
        : ""
    }

Génère un tableau JSON exact de ${exerciseCount} exercice(s) avec les clés :
[
  {
    "title": "Titre court de l'exercice",
    "statement": "Énoncé complet avec LaTeX si nécessaire",
    "correction": "Corrigé pas-à-pas détaillé",
    "options": ["Option A", "Option B", "Option C", "Option D"] ou null si non-QCM,
    "correct_index": 0 à 3, ou null si non-QCM,
    "hints": ["Indice 1 (léger)", "Indice 2 (plus précis)"],
    "skills": ["Compétence courte 1", "Compétence courte 2"]
  }
]`;

    let exercises: Record<string, unknown>[] | null = null;
    let provider = "none";
    let modelUsed: string | null = null;
    let tokensUsed = 0;
    let costEstimate = 0;

    if (AI_MOCK_MODE) {
      exercises = buildMockExercises(
        exerciseCount,
        format ?? "qcm",
        difficulty ?? "facile",
      );
      provider = "mock";
      modelUsed = "mock";
    } else if (GEMINI_API_KEY) {
      try {
        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{
                role: "user",
                parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }],
              }],
              generationConfig: {
                responseMimeType: "application/json",
                maxOutputTokens: 4096, // gemini-3.6-flash consomme des jetons de réflexion cachés — voir ai-tutor-chat
              },
            }),
          },
        );

        if (geminiRes.ok) {
          const geminiData = await geminiRes.json();
          const rawText =
            geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          exercises = JSON.parse(rawText);
          provider = "gemini";
          modelUsed = "gemini-3.6-flash";
          tokensUsed = geminiData.usageMetadata?.totalTokenCount ?? 0;
          costEstimate = 0;
        }
      } catch (geminiErr) {
        console.warn("Gemini API Error:", geminiErr);
      }
    }

    const durationMs = Date.now() - startTime;
    console.log(
      `Génération d'exercices IA terminée en ${durationMs}ms via provider=${provider}`,
    );

    // Aucun résultat réel et mode mock inactif : erreur explicite, jamais de contenu statique
    // déguisé en résultat réel (voir 06_ai_pipeline.md).
    if (!exercises) {
      const errorMessage =
        "Échec de la génération IA : Gemini n'a retourné aucun résultat exploitable.";
      try {
        await supabase.from("ai_agent_calls").insert({
          request_id: requestId,
          agent_type: "exercise_generation",
          provider,
          duration_ms: durationMs,
          status: "failed",
          error_message: errorMessage,
        });
      } catch (insertErr) {
        console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
      }
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: "exercise_generation",
        provider,
        model: modelUsed,
        tokens_used: tokensUsed,
        cost_estimate: costEstimate,
        duration_ms: durationMs,
        status: "success",
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(
      JSON.stringify({
        exercises,
        _mock: provider === "mock",
        _request_id: requestId,
        _agent_version: AGENT_VERSION,
        _model: modelUsed,
        _duration_ms: durationMs,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("AI Exercise Generation Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
