import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
// Claude retiré le 2026-08-29 (demande explicite du porteur de projet) : ANTHROPIC_API_KEY n'a
// jamais été configurée sur ce projet (vérifié via `supabase secrets list`) — le repli sur Claude
// n'a donc jamais réellement servi, cette fonction utilisait déjà Gemini en pratique à chaque appel
// réel. Modèle aligné sur gemini-3.6-flash (déjà confirmé fonctionnel dans ai-tutor-chat/
// ai-generate-text) plutôt que gemini-1.5-flash, jamais revérifié depuis son introduction.
// Mode mock explicite (voir 06_ai_pipeline.md) : absent par défaut, jamais un comportement silencieux.
const AI_MOCK_MODE = Deno.env.get("AI_MOCK_MODE") === "true";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Retour porteur (2026-09-12, point #3) : la génération ne tenait compte que de raw_notes/
// subject_id — un cours de 3ème et de Terminale C sortaient quasi identiques. Résout la chaîne
// complète pays → section → enseignement → classe → série → matière → chapitre, et la position du
// chapitre dans le programme (chapitres voisins), pour une vraie adaptation au niveau réel.
async function resolveCurricularContext(
  chapterId: string | null,
  subjectIdIn: string | null,
): Promise<{ label: string; subjectId: string | null; programmeNeighbours: string[] }> {
  if (!chapterId) return { label: "", subjectId: subjectIdIn, programmeNeighbours: [] };
  const { data: chapter } = await supabase
    .from("chapters")
    .select("title, subject_id, class_node_id, display_order")
    .eq("id", chapterId)
    .maybeSingle();
  if (!chapter) return { label: "", subjectId: subjectIdIn, programmeNeighbours: [] };

  const subjectId = subjectIdIn ?? chapter.subject_id;
  const { data: subject } = subjectId
    ? await supabase.from("subjects").select("name").eq("id", subjectId).maybeSingle()
    : { data: null };

  const pathParts: string[] = [];
  let currentId: string | null = chapter.class_node_id;
  const visited = new Set<string>();
  while (currentId && !visited.has(currentId)) {
    visited.add(currentId);
    const { data: node } = await supabase
      .from("academic_nodes").select("name, parent_id").eq("id", currentId).maybeSingle();
    if (!node) break;
    pathParts.unshift(node.name as string);
    currentId = node.parent_id as string | null;
  }

  const { data: siblings } = await supabase
    .from("chapters").select("title, display_order")
    .eq("subject_id", subjectId).eq("class_node_id", chapter.class_node_id)
    .order("display_order");
  const neighbours = ((siblings ?? []) as { title: string }[]).map((s) => s.title);

  const label = [...pathParts, subject?.name, `Chapitre : ${chapter.title}`]
    .filter(Boolean).join(" › ");
  return { label, subjectId, programmeNeighbours: neighbours };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// CF-004 (docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md) : contrat de sortie minimal §4 du cahier des
// charges Agents IA — request_id/agent_version/model traçables, y compris pour un appel échoué
// (jusqu'ici jamais journalisé). Purement additif : ne change aucune clé existante de la réponse.
const AGENT_VERSION = "1.0.0";

// Contenu utilisé UNIQUEMENT quand AI_MOCK_MODE=true — jamais comme repli silencieux en cas
// d'échec des appels API réels (voir 06_ai_pipeline.md).
function buildMockCourse(): Record<string, unknown> {
  return {
    _mock: true,
    title: "Cours Structuré Haute Qualité (MOCK)",
    summary:
      "Synthèse complète et rigoureuse des notions fondamentales du chapitre.",
    sections: [
      {
        heading: "1. Notions Fondamentales & Définitions",
        type: "definition",
        body:
          "Définition rigoureuse conforme aux exigences des examens nationaux.",
        latex_formulas: ["$f(x) = ax^2 + bx + c$", "$\\Delta = b^2 - 4ac$"],
      },
      {
        heading: "2. Théorèmes & Propriétés Majeures",
        type: "theoreme",
        body:
          "Énoncé précis et conditions d'application requises pour la rédaction.",
        latex_formulas: ["x_{1,2} = \\frac{-b \\pm \\sqrt{\\Delta}}{2a}"],
      },
      {
        heading: "3. Méthode de Résolution pas-à-pas",
        type: "methode",
        body:
          "1. Identifier précisément les termes. 2. Appliquer la formule adaptée. 3. Vérifier la cohérence de l'unité et du domaine de définition.",
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
        question:
          "Quelle est la condition nécessaire pour qu'une équation du second degré admette deux solutions réelles distinctes ?",
        options: ["$\\Delta < 0$", "$\\Delta = 0$", "$\\Delta > 0$", "$a = 0$"],
        correct_index: 2,
        explanation:
          "Lorsque le discriminant $\\Delta$ est strictement positif, il existe deux racines distinctes réelles.",
      },
    ],
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  try {
    const {
      chapter_id, subject_id, raw_notes, prompt_directives,
      mode: modeIn, existing_blocks,
    } = await req.json();
    // 'plan' = plan de chapitre seul (rapide, à valider avant rédaction complète) ;
    // 'full' = leçon complète (comportement historique) ;
    // 'examples_only' = ne régénère QUE les exemples, le reste des blocs existants est conservé
    // tel quel côté client (fusion, jamais un remplacement total) — répond à la demande explicite
    // « je dois pouvoir modifier une partie et régénérer uniquement cette partie ».
    const mode: "plan" | "full" | "examples_only" =
      ["plan", "full", "examples_only"].includes(modeIn) ? modeIn : "full";

    if (!raw_notes && !chapter_id) {
      return new Response(
        JSON.stringify({
          error: "Paramètres manquants : raw_notes ou chapter_id requis",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 0. Contexte curriculaire réel (pays/section/enseignement/classe/série/matière/chapitre +
    // position dans le programme) — sans lui, un cours de 3ème et de Terminale C étaient quasi
    // identiques (retour porteur du 2026-09-12).
    const ctx = await resolveCurricularContext(chapter_id ?? null, subject_id ?? null);
    const effectiveSubjectId = ctx.subjectId;

    // 1. Récupération du catalogue pédagogique de la matière (Section 16.0 du CDC)
    let catalogPrompt =
      "Structure type : Définition, Théorème, Propriété, Formule LaTeX, Méthode pas-à-pas, Piège classique.";
    if (effectiveSubjectId) {
      const { data: catalogItems } = await supabase
        .from("content_catalog")
        .select("element_type, description")
        .eq("subject_id", effectiveSubjectId);

      if (catalogItems && catalogItems.length > 0) {
        catalogPrompt = catalogItems
          .map((item: { element_type: string; description?: string }) =>
            `- ${item.element_type}: ${item.description ?? ""}`
          )
          .join("\n");
      }
    }

    const contextBlock = ctx.label
      ? `Périmètre curriculaire réel (adapte impérativement le niveau, le vocabulaire et la ` +
        `profondeur à cette classe précise — ne traite jamais un chapitre de 3ème comme un ` +
        `chapitre de Terminale, ni l'inverse) :\n${ctx.label}\n` +
        (ctx.programmeNeighbours.length
          ? `Programme complet de cette matière pour cette classe (ordre officiel) : ` +
            `${ctx.programmeNeighbours.join(" → ")}\n`
          : "")
      : "";

    // 2. Construction du prompt expert (Section 16.0 & 2.1 du CDC), variable selon le mode.
    const systemPromptCommon =
      `Tu es un expert pédagogique national et concepteur de programmes scolaires d'excellence.
${contextBlock}
Typologie pédagogique obligatoire :
${catalogPrompt}

Règles strictes de rédaction :
- Toutes les formules mathématiques, chimiques ou physiques DOIVENT être encadrées par des balises LaTeX : $...$ pour inline ou $$...$$ pour blocs séparés.
- Ne renvoyer QUE du JSON valide, sans texte additionnel ni balises de commentaires Markdown.`;

    let systemPrompt: string;
    let userPrompt: string;
    let maxTokens: number;

    if (mode === "plan") {
      systemPrompt = `${systemPromptCommon}
Ta mission ICI : produire uniquement le PLAN du chapitre (pas encore la rédaction complète), pour
validation humaine avant de dépenser du calcul sur la rédaction détaillée.`;
      userPrompt = `Notes / objectifs de départ :
${raw_notes ?? "Chapitre du programme officiel sélectionné."}
${prompt_directives ? `Directives du professeur : ${prompt_directives}` : ""}

Génère STRICTEMENT ce JSON :
{
  "title": "Titre complet du chapitre",
  "summary": "Résumé exécutif en 2-3 phrases",
  "prerequisites": ["Prérequis 1", "Prérequis 2"],
  "objectives": ["Objectif pédagogique 1", "Objectif 2"],
  "competencies": ["Compétence visée 1", "Compétence 2"],
  "plan": [
    {"heading": "Titre de la section prévue", "type": "theoreme | definition | formule | methode | exemple", "summary": "1 phrase de ce que contiendra cette section"}
  ]
}`;
      maxTokens = 3072;
    } else if (mode === "examples_only") {
      const existingSummary = Array.isArray(existing_blocks)
        ? (existing_blocks as { type: string; heading?: string; body?: string }[])
            .filter((b) => b.type !== "exemple")
            .map((b) => `- [${b.type}] ${b.heading ?? ""} : ${(b.body ?? "").slice(0, 200)}`)
            .join("\n")
        : "";
      systemPrompt = `${systemPromptCommon}
Ta mission ICI : générer UNIQUEMENT de nouveaux exemples d'application (type "exemple"), cohérents
avec le contenu déjà rédigé fourni en référence ci-dessous. Ne reformule PAS les définitions/
théorèmes déjà écrits — ils sont conservés tels quels par l'admin, tu ne dois produire que des
exemples supplémentaires ou de remplacement.`;
      userPrompt = `Contenu déjà rédigé pour ce chapitre (référence, à ne pas dupliquer) :
${existingSummary || "(aucun autre bloc encore rédigé)"}

${prompt_directives ? `Directives du professeur pour ces exemples : ${prompt_directives}` : ""}
${raw_notes ? `Notes additionnelles : ${raw_notes}` : ""}

Génère STRICTEMENT ce JSON (uniquement des sections de type "exemple") :
{
  "sections": [
    {"heading": "Exemple d'application N", "type": "exemple", "body": "Énoncé + résolution pas-à-pas avec LaTeX", "latex_formulas": ["..."]}
  ]
}`;
      maxTokens = 6144;
    } else {
      systemPrompt = `${systemPromptCommon}
Ta mission ICI : structurer un cours complet, rigoureux et interactif.
- Mettre en exergue les astuces d'examens officiels et les pièges classiques fréquents.
- Fournir un quiz d'évaluation formative avec explications détaillées.`;
      userPrompt = `Voici les notes brutes et objectifs du cours à structurer :
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
      maxTokens = 16384;
    }

    let structuredCourse: Record<string, unknown> | null = null;
    let provider = "none";
    let modelUsed: string | null = null;
    let tokensUsed = 0;
    let costEstimate = 0;
    // Diagnostic réel de l'échec Gemini (au lieu d'un message générique) — voir plus bas.
    let geminiDiag = "";

    // Mode mock : déclenché uniquement par AI_MOCK_MODE=true, jamais silencieux, toujours signalé
    // explicitement dans la réponse (_mock: true) — voir 06_ai_pipeline.md.
    if (AI_MOCK_MODE) {
      structuredCourse = buildMockCourse();
      provider = "mock";
      modelUsed = "mock";
    } else {
      // Passe par le Model Router multi-fournisseurs (ai-generate-text) : bascule automatique
      // Gemini → Groq → Cerebras → OpenRouter → Mistral selon les clés configurées et les quotas.
      try {
        const routerRes = await fetch(`${SUPABASE_URL}/functions/v1/ai-generate-text`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
          body: JSON.stringify({
            capability: "structuring_json",
            system_prompt: systemPrompt,
            user_prompt: userPrompt,
            json: true,
            max_tokens: maxTokens,
            temperature: 0.4,
          }),
        });
        const routerData = await routerRes.json();
        if (!routerRes.ok) {
          geminiDiag = `Model Router : ${routerData.error ?? `HTTP ${routerRes.status}`}` +
            (routerData.provider_chain ? ` [${routerData.provider_chain.map((a: { provider: string; reason: string }) => `${a.provider}=${a.reason}`).join(", ")}]` : "");
        } else {
          const jsonText = (routerData.text ?? "")
            .replace(/^```(?:json)?\s*/i, "")
            .replace(/\s*```$/i, "")
            .trim();
          try {
            structuredCourse = JSON.parse(jsonText);
            provider = routerData._provider ?? "router";
            modelUsed = routerData._model ?? null;
            tokensUsed = 0;
            costEstimate = 0;
          } catch (parseErr) {
            geminiDiag = `JSON illisible du fournisseur ${routerData._provider} : ` +
              `${(parseErr as Error).message}. Extrait : ${jsonText.slice(0, 160)}`;
          }
        }
      } catch (routerErr) {
        geminiDiag = `exception Model Router : ${(routerErr as Error).message}`;
        console.warn("Model Router error:", routerErr);
      }
    }

    const durationMs = Date.now() - startTime;
    console.log(
      `Structuration IA terminée en ${durationMs}ms via provider=${provider}`,
    );

    // Aucun résultat réel et mode mock inactif : erreur explicite, jamais de contenu statique
    // déguisé en résultat réel (voir 06_ai_pipeline.md).
    if (!structuredCourse) {
      const errorMessage = geminiDiag
        ? `Échec de la structuration IA — ${geminiDiag}`
        : "Échec de la structuration IA : Gemini n'a retourné aucun résultat exploitable.";
      try {
        await supabase.from("ai_agent_calls").insert({
          request_id: requestId,
          agent_type: `course_structuring:${mode}`,
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

    // 4. Traçabilité des coûts et des appels IA dans ai_agent_calls (colonnes réelles du schéma :
    // agent_type, provider, tokens_used, cost_estimate — voir 06_ai_pipeline.md).
    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: `course_structuring:${mode}`,
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
        ...structuredCourse,
        _request_id: requestId,
        _agent_version: AGENT_VERSION,
        _model: modelUsed,
        _duration_ms: durationMs,
        _mode: mode,
        _curricular_context: ctx.label || null,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("AI Course Structuring Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
