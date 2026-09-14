import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
// Claude retiré le 2026-08-29 (demande explicite du porteur de projet) — voir le commentaire
// équivalent dans ai-course-structuring/index.ts : ANTHROPIC_API_KEY n'a jamais été configurée.
// Mode mock explicite (voir 06_ai_pipeline.md) : absent par défaut, jamais un comportement silencieux.
const AI_MOCK_MODE = Deno.env.get("AI_MOCK_MODE") === "true";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Retour porteur (2026-09-12, point #3) : les exercices ne tenaient compte que de subject_id/
// raw_notes — un exercice de 3ème et de Terminale C sortaient au même niveau. Même résolution de
// contexte que ai-course-structuring (dupliquée ici : pas de dossier `_shared` dans ce projet, même
// convention que les autres fonctions Edge autonomes).
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

// CF-004 : contrat de sortie minimal §4 du cahier des charges Agents IA — additif uniquement.
const AGENT_VERSION = "2.0.0";

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
      existing_exercises,
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

    // 0. Contexte curriculaire réel (pays/section/enseignement/classe/série/matière/chapitre +
    // position dans le programme) — sans lui, un exercice de 3ème et de Terminale C sortaient au
    // même niveau de difficulté et de vocabulaire (retour porteur du 2026-09-12).
    const ctx = await resolveCurricularContext(chapter_id ?? null, subject_id ?? null);
    const effectiveSubjectId = ctx.subjectId;

    // 1. Récupération du catalogue pédagogique de la matière (Section 16.0 du CDC)
    let catalogPrompt =
      "Structure type : énoncé clair, corrigé pas à pas, niveau calibré.";
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
      ? `Périmètre curriculaire réel (adapte impérativement le niveau, le vocabulaire, la longueur ` +
        `des énoncés et la profondeur du corrigé à cette classe précise — ne traite jamais un ` +
        `exercice de 3ème comme un exercice de Terminale, ni l'inverse) :\n${ctx.label}\n` +
        (ctx.programmeNeighbours.length
          ? `Programme complet de cette matière pour cette classe (ordre officiel, pour situer le ` +
            `chapitre concerné) : ${ctx.programmeNeighbours.join(" → ")}\n`
          : "")
      : "";

    // Évite de régénérer des doublons quand l'admin demande « encore quelques exercices » sur un
    // chapitre qui en a déjà — répond au même principe de non-régression que le mode
    // examples_only de ai-course-structuring (jamais perdre le travail déjà validé).
    const existingSummary = Array.isArray(existing_exercises) && existing_exercises.length > 0
      ? `Exercices déjà existants sur ce chapitre (NE PAS dupliquer un énoncé équivalent) :\n` +
        (existing_exercises as { title?: string }[])
          .slice(0, 30)
          .map((e) => `- ${e.title ?? "(sans titre)"}`)
          .join("\n") + "\n"
      : "";

    const systemPrompt =
      `Tu es un expert pédagogique national et concepteur d'exercices scolaires d'excellence.
${contextBlock}Ta mission est de générer ${exerciseCount} exercice(s) de type "${
        type ?? "entraînement"
      }", format "${format ?? "qcm"}", niveau de difficulté "${
        difficulty ?? "facile"
      }", au format JSON strict.

Typologie pédagogique de référence :
${catalogPrompt}

${existingSummary}Règles strictes :
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
{
  "exercises": [
    {
      "title": "Titre court de l'exercice",
      "statement": "Énoncé complet avec LaTeX si nécessaire",
      "correction": "Corrigé pas-à-pas détaillé",
      "options": ["Option A", "Option B", "Option C", "Option D"] ou null si non-QCM,
      "correct_index": 0 à 3, ou null si non-QCM,
      "hints": ["Indice 1 (léger)", "Indice 2 (plus précis)"],
      "skills": ["Compétence courte 1", "Compétence courte 2"]
    }
  ]
}`;

    let exercises: Record<string, unknown>[] | null = null;
    let provider = "none";
    let modelUsed: string | null = null;
    let tokensUsed = 0;
    let costEstimate = 0;
    // Diagnostic réel de l'échec (au lieu d'un message générique) — voir plus bas.
    let diag = "";

    if (AI_MOCK_MODE) {
      exercises = buildMockExercises(
        exerciseCount,
        format ?? "qcm",
        difficulty ?? "facile",
      );
      provider = "mock";
      modelUsed = "mock";
    } else {
      // Passe par le Model Router multi-fournisseurs (ai-generate-text) : bascule automatique
      // Gemini → Groq → Cerebras → OpenRouter → Mistral selon les clés configurées et les quotas —
      // remplace l'ancien appel direct à Gemini seul (jamais de repli en cas d'épuisement du quota).
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
            max_tokens: 8192,
            temperature: 0.5,
          }),
        });
        const routerData = await routerRes.json();
        if (!routerRes.ok) {
          diag = `Model Router : ${routerData.error ?? `HTTP ${routerRes.status}`}` +
            (routerData.provider_chain
              ? ` [${routerData.provider_chain.map((a: { provider: string; reason: string }) => `${a.provider}=${a.reason}`).join(", ")}]`
              : "");
        } else {
          const jsonText = (routerData.text ?? "")
            .replace(/^```(?:json)?\s*/i, "")
            .replace(/\s*```$/i, "")
            .trim();
          try {
            const parsed = JSON.parse(jsonText);
            exercises = Array.isArray(parsed) ? parsed : (parsed.exercises ?? null);
            if (!exercises) throw new Error("clé 'exercises' absente de la réponse JSON");
            provider = routerData._provider ?? "router";
            modelUsed = routerData._model ?? null;
          } catch (parseErr) {
            diag = `JSON illisible du fournisseur ${routerData._provider} : ` +
              `${(parseErr as Error).message}. Extrait : ${jsonText.slice(0, 160)}`;
          }
        }
      } catch (routerErr) {
        diag = `exception Model Router : ${(routerErr as Error).message}`;
        console.warn("Model Router error:", routerErr);
      }
    }

    const durationMs = Date.now() - startTime;
    console.log(
      `Génération d'exercices IA terminée en ${durationMs}ms via provider=${provider}`,
    );

    // Aucun résultat réel et mode mock inactif : erreur explicite, jamais de contenu statique
    // déguisé en résultat réel (voir 06_ai_pipeline.md).
    if (!exercises) {
      const errorMessage = diag
        ? `Échec de la génération IA — ${diag}`
        : "Échec de la génération IA : aucun fournisseur n'a retourné de résultat exploitable.";
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
        _curricular_context: ctx.label || null,
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
