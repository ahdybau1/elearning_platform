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
function buildMockCatalogTypes(count: number, subjectName: string): Record<string, unknown>[] {
  return Array.from({ length: count }, (_, i) => ({
    element_type: `Type ${i + 1} (MOCK)`,
    description: `Description factice pour "${subjectName}" n°${i + 1} — remplacez avant utilisation réelle.`,
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
      subject_name,
      education_level,
      count,
      raw_notes,
    } = await req.json();

    if (!subject_name) {
      return new Response(
        JSON.stringify({ error: "Paramètre manquant : subject_name requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const typeCount = Math.min(Math.max(Number(count) || 8, 1), 20);

    // Quelques exemples de référence (mêmes que ceux déjà utilisés côté admin pour les matières
    // courantes), passés en few-shot pour calibrer le style attendu — jamais renvoyés tels quels,
    // seulement une aide de calibrage pour l'IA.
    const fewShotExamples = `Exemples de calibrage (Mathématiques) :
- Théorème: Énoncé mathématique majeur avec démonstration type
- Piège & Erreur Classique: Mise en garde contre les confusions fréquentes
Exemples de calibrage (Français & Littérature) :
- Figure de Style: Métaphore, allégorie, oxymore avec exemples
- Plan Dialectique: Structure de dissertation (Thèse, Antithèse, Synthèse)`;

    const systemPrompt = `Tu es un expert pédagogique national et concepteur de programmes scolaires d'excellence.
Ta mission est de proposer ${typeCount} "types d'éléments pédagogiques" distincts et non redondants pour la matière "${subject_name}"${education_level ? ` au niveau "${education_level}"` : ""}.
Ces types serviront à structurer automatiquement les cours générés par IA pour cette matière (ex: Théorème, Définition, Protocole Expérimental...).

${fewShotExamples}

Règles strictes :
- Chaque type doit être court (2-4 mots) et sa description doit expliquer en une phrase ce qu'il représente pédagogiquement.
- Aucune redondance entre les types proposés.
- Adapte les types à la nature réelle de la matière "${subject_name}" (pas de recopie des exemples ci-dessus si non pertinents).
- Ne renvoyer QUE du JSON valide, sans texte additionnel ni balises de commentaires Markdown.`;

    const userPrompt = `${raw_notes ? `Directives spécifiques de l'admin : ${raw_notes}\n\n` : ""}Génère un tableau JSON exact de ${typeCount} type(s) avec les clés :
[
  { "element_type": "Nom court du type", "description": "Description pédagogique en une phrase" }
]`;

    let types: Record<string, unknown>[] | null = null;
    let provider = "none";
    let tokensUsed = 0;
    let costEstimate = 0;

    if (AI_MOCK_MODE) {
      types = buildMockCatalogTypes(typeCount, subject_name);
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
              max_tokens: 2000,
              system: systemPrompt,
              messages: [{ role: "user", content: userPrompt }],
            }),
          });

          if (anthropicRes.ok) {
            const anthropicData = await anthropicRes.json();
            const rawText = anthropicData.content?.[0]?.text ?? "";
            const cleanedJson = rawText.replace(/^```json\s*/i, "").replace(/\s*```$/i, "").trim();
            types = JSON.parse(cleanedJson);
            provider = "anthropic";
            tokensUsed = (anthropicData.usage?.input_tokens ?? 0) + (anthropicData.usage?.output_tokens ?? 0);
            costEstimate = tokensUsed * 0.000003;
          }
        } catch (anthropicErr) {
          console.warn("Anthropic API Error:", anthropicErr);
        }
      }

      if (!types && GEMINI_API_KEY) {
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
            types = JSON.parse(rawText);
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
    console.log(`Génération de types de catalogue IA terminée en ${durationMs}ms via provider=${provider}`);

    // Aucun résultat réel et mode mock inactif : erreur explicite, jamais de contenu statique
    // déguisé en résultat réel (voir 06_ai_pipeline.md).
    if (!types) {
      return new Response(
        JSON.stringify({
          error: "Échec de la génération IA : aucun fournisseur (Claude, Gemini) n'a retourné de résultat exploitable.",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      await supabase.from("ai_agent_calls").insert({
        agent_type: "catalog_generation",
        provider,
        tokens_used: tokensUsed,
        cost_estimate: costEstimate,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(JSON.stringify({ types, _mock: provider === "mock" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("AI Catalog Types Generation Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
