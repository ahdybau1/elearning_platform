import { createClient } from "npm:@supabase/supabase-js@2.39.0";

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
function buildMockCourse(): Record<string, unknown> {
  return {
    _mock: true,
    title: "Cours Structuré Haute Qualité (MOCK)",
    summary: "Synthèse complète et rigoureuse des notions fondamentales du chapitre.",
    sections: [
      {
        heading: "1. Notions Fondamentales & Définitions",
        type: "definition",
        body: "Définition rigoureuse conforme aux exigences des examens nationaux.",
        latex_formulas: ["$f(x) = ax^2 + bx + c$", "$\\Delta = b^2 - 4ac$"],
      },
      {
        heading: "2. Théorèmes & Propriétés Majeures",
        type: "theoreme",
        body: "Énoncé précis et conditions d'application requises pour la rédaction.",
        latex_formulas: ["x_{1,2} = \\frac{-b \\pm \\sqrt{\\Delta}}{2a}"],
      },
      {
        heading: "3. Méthode de Résolution pas-à-pas",
        type: "methode",
        body: "1. Identifier précisément les termes. 2. Appliquer la formule adaptée. 3. Vérifier la cohérence de l'unité et du domaine de définition.",
        latex_formulas: [],
      },
    ],
    common_traps: [
      "Ne pas oublier la condition d'existence ou le domaine de définition.",
      "Faire attention aux erreurs de signe lors des simplifications algébriques.",
    ],
    exam_tips: [
      "Toujours encadrer les résultats finaux avec leurs unités.",
      "Justifier chaque étape par le nom précis du théorème utilisé.",
    ],
    quiz_questions: [
      {
        question: "Quelle est la condition nécessaire pour qu'une équation du second degré admette deux solutions réelles distinctes ?",
        options: ["$\\Delta < 0$", "$\\Delta = 0$", "$\\Delta > 0$", "$a = 0$"],
        correct_index: 2,
        explanation: "Lorsque le discriminant $\\Delta$ est strictement positif, il existe deux racines distinctes réelles.",
      },
    ],
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const { chapter_id, subject_id, raw_notes, prompt_directives } = await req.json();

    if (!raw_notes && !chapter_id) {
      return new Response(
        JSON.stringify({ error: "Paramètres manquants : raw_notes ou chapter_id requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Récupération du catalogue pédagogique de la matière (Section 16.0 du CDC)
    let catalogPrompt = "Structure type : Définition, Théorème, Propriété, Formule LaTeX, Méthode pas-à-pas, Piège classique.";
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

    // 2. Construction du prompt expert (Section 16.0 & 2.1 du CDC)
    const systemPrompt = `Tu es un expert pédagogique national et concepteur de programmes scolaires d'excellence.
Ta mission est de structurer un cours complet, rigoureux et interactif au format JSON strict.

Typologie pédagogique obligatoire :
${catalogPrompt}

Règles strictes de rédaction :
- Toutes les formules mathématiques, chimiques ou physiques DOIVENT être encadrées par des balises LaTeX : $...$ pour inline ou $$...$$ pour blocs séparés.
- Mettre en exergue les astuces d'examens officiels et les pièges classiques fréquents.
- Fournir un quiz d'évaluation formative avec explications détaillées.
- Ne renvoyer QUE du JSON valide, sans texte additionnel ni balises de commentaires Markdown.`;

    const userPrompt = `Voici les notes brutes et objectifs du cours à structurer :
${raw_notes ?? "Cours sur le programme officiel du chapitre sélectionné."}

${prompt_directives ? `Directives spécifiques du professeur : ${prompt_directives}` : ""}

Génère la structure JSON exacte avec les clés :
{
  "title": "Titre complet du cours",
  "summary": "Résumé exécutif en 2-3 phrases clés",
  "sections": [
    {
      "heading": "Titre de section",
      "type": "theoreme | definition | formule | methode | exemple",
      "body": "Explications pédagogiques détaillées avec LaTeX",
      "latex_formulas": ["formule 1", "formule 2"]
    }
  ],
  "common_traps": ["Piège 1 à éviter absolument", "Piège 2"],
  "exam_tips": ["Conseil officiel d'épreuve"],
  "quiz_questions": [
    {
      "question": "Énoncé de la question à choix multiple",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "explanation": "Justification pédagogique de la bonne réponse"
    }
  ]
}`;

    let structuredCourse: Record<string, unknown> | null = null;
    let provider = "none";
    let tokensUsed = 0;
    let costEstimate = 0;

    // Mode mock : déclenché uniquement par AI_MOCK_MODE=true, jamais silencieux, toujours signalé
    // explicitement dans la réponse (_mock: true) — voir 06_ai_pipeline.md.
    if (AI_MOCK_MODE) {
      structuredCourse = buildMockCourse();
      provider = "mock";
    } else {
      // 3. Appel de l'IA réel (Claude Sonnet puis, en repli, Gemini Flash)
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
            structuredCourse = JSON.parse(cleanedJson);
            provider = "anthropic";
            tokensUsed = (anthropicData.usage?.input_tokens ?? 0) + (anthropicData.usage?.output_tokens ?? 0);
            costEstimate = tokensUsed * 0.000003;
          }
        } catch (anthropicErr) {
          console.warn("Anthropic API Error:", anthropicErr);
        }
      }

      if (!structuredCourse && GEMINI_API_KEY) {
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
                    parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }],
                  },
                ],
                generationConfig: {
                  responseMimeType: "application/json",
                },
              }),
            }
          );

          if (geminiRes.ok) {
            const geminiData = await geminiRes.json();
            const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
            structuredCourse = JSON.parse(rawText);
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
    console.log(`Structuration IA terminée en ${durationMs}ms via provider=${provider}`);

    // Aucun résultat réel et mode mock inactif : erreur explicite, jamais de contenu statique
    // déguisé en résultat réel (voir 06_ai_pipeline.md).
    if (!structuredCourse) {
      return new Response(
        JSON.stringify({
          error: "Échec de la structuration IA : aucun fournisseur (Claude, Gemini) n'a retourné de résultat exploitable.",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Traçabilité des coûts et des appels IA dans ai_agent_calls (colonnes réelles du schéma :
    // agent_type, provider, tokens_used, cost_estimate — voir 06_ai_pipeline.md).
    try {
      await supabase.from("ai_agent_calls").insert({
        agent_type: "course_structuring",
        provider,
        tokens_used: tokensUsed,
        cost_estimate: costEstimate,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(JSON.stringify(structuredCourse), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("AI Course Structuring Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
