// Tuteur Numérique élève (§8 du cahier des charges) — proxy vers Google Gemini (palier gratuit), pour que
// la clé API ne soit jamais exposée dans le bundle Flutter web (voir student_app/
// ai_tutor_chat_screen.dart). Choix Gemini explicitement demandé par l'utilisateur : "totalement
// gratuit", palier temporaire en attendant un agent IA propriétaire construit ultérieurement (voir
// mémoire projet_ai_tutor_backend_choice).
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

// CF-004 : contrat de sortie minimal §4 du cahier des charges Agents IA — additif uniquement.
// 1.1.0 (IA-007) : accepte en plus rag_context/student_model_summary/tool_context, fournis par
// gateway/app/agents/tutor_agent.py — voir ai_agent_versions (migration 66) pour le contrat complet.
// 1.2.0 (2026-09-06) : sait maintenant CALCULER lui-même le RAG (+ citations), le Student Model et le
// cache quand l'appelant ne les fournit pas. Motif (audit du 2026-09-06) : AUCUN client Flutter
// n'appelle la Gateway Python — l'app élève appelle cette fonction en direct
// (ai_tutor_chat_screen.dart), donc sans ces champs. Toute la tranche verticale IA-007 (RAG,
// citations, personnalisation) était de fait invisible pour les élèves. Porter l'enrichissement ici
// le rend réellement atteignable sans déployer d'infra payante (contrainte "zéro dépense" du projet).
// Les champs fournis par un appelant (Gateway) restent prioritaires : aucune régression.
const AGENT_VERSION = "1.2.0";
const MODEL = "gemini-3.6-flash";
const RAG_TOP_K = 3;

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Un profile_id vient du CLIENT : il ne peut jamais être utilisé tel quel pour lire le Student Model
// d'un profil (données pédagogiques d'un mineur). Même vérification que verify_profile_access côté
// Gateway (gateway/app/auth.py) : le profil doit appartenir au compte réellement authentifié.
async function ownsProfile(jwt: string, profileId: string): Promise<boolean> {
  try {
    const { data: userData } = await supabase.auth.getUser(jwt);
    const authUserId = userData?.user?.id;
    if (!authUserId) return false;

    const { data: profile } = await supabase
      .from("profiles")
      .select("account_id")
      .eq("id", profileId)
      .maybeSingle();
    if (!profile?.account_id) return false;

    const { data: account } = await supabase
      .from("accounts")
      .select("auth_user_id")
      .eq("id", profile.account_id)
      .maybeSingle();
    return account?.auth_user_id === authUserId;
  } catch (err) {
    console.error("Vérification de propriété du profil impossible:", err);
    return false;
  }
}

// RAG (§10 : citations obligatoires pour les faits pédagogiques récupérés), scopé à la
// matière/classe actives — jamais tout le corpus. Même chaîne que gateway/app/rag/retrieve.py :
// embedding de la question via ai-embeddings-generate (la clé Gemini reste côté Supabase), puis RPC
// match_rag_chunks (migration 59), puis résolution du titre de la source pour la citation.
async function ragSearch(
  query: string,
  classNodeId: string | null,
  subjectId: string | null,
): Promise<Record<string, unknown>[]> {
  const embedRes = await fetch(`${SUPABASE_URL}/functions/v1/ai-embeddings-generate`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "apikey": SUPABASE_SERVICE_ROLE_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ texts: [query] }),
  });
  if (!embedRes.ok) {
    console.warn("RAG désactivé pour cet appel : embedding indisponible", embedRes.status);
    return [];
  }
  const embedBody = await embedRes.json();
  const queryEmbedding = embedBody?.embeddings?.[0];
  if (!queryEmbedding) return [];

  const { data: matches, error } = await supabase.rpc("match_rag_chunks", {
    query_embedding: queryEmbedding,
    match_class_node_id: classNodeId,
    match_subject_id: subjectId,
    match_count: RAG_TOP_K,
  });
  if (error || !Array.isArray(matches) || matches.length === 0) {
    if (error) console.warn("match_rag_chunks en échec:", error.message);
    return [];
  }

  const sourceIds = [...new Set(matches.map((m: Record<string, unknown>) => m.source_id))];
  const { data: sources } = await supabase
    .from("ai_rag_sources")
    .select("id,title,source_type")
    .in("id", sourceIds);
  const sourcesById = new Map(
    (sources ?? []).map((s: Record<string, unknown>) => [s.id, s]),
  );

  return matches.map((m: Record<string, unknown>) => {
    const source = sourcesById.get(m.source_id) as Record<string, unknown> | undefined;
    return {
      chunk_id: m.id,
      source_id: m.source_id,
      source_title: source?.title ?? null,
      source_type: source?.source_type ?? null,
      content: m.content,
      similarity: m.similarity,
    };
  });
}

// Student Model (U9) — jamais un chiffre inventé : uniquement ce que get_student_skill_mastery
// renvoie réellement depuis exercise_attempts. Même formatage que format_mastery_summary côté
// Gateway, pour que les deux chemins produisent le même prompt.
async function masterySummary(
  profileId: string,
  subjectId: string,
): Promise<string | null> {
  const { data, error } = await supabase.rpc("get_student_skill_mastery", {
    p_profile_id: profileId,
    p_subject_id: subjectId,
  });
  if (error || !Array.isArray(data) || data.length === 0) return null;

  const lines = [...data]
    .sort((a, b) => (a.mastery_level ?? 1) - (b.mastery_level ?? 1))
    .map((row) => {
      const level = row.mastery_level;
      const pct = level === null || level === undefined
        ? "non évalué"
        : `${Math.round(Number(level) * 100)}%`;
      return `- ${row.skill_name} : ${pct} de réussite sur ${row.attempts_count} tentative(s)`;
    });
  return "Suivi réel de l'élève sur cette matière (à utiliser pour adapter le niveau, jamais à réciter tel quel) :\n" +
    lines.join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  // Journalise un échec dans ai_agent_calls (jusqu'ici jamais fait pour ce tuteur — les pannes
  // Gemini/quota étaient invisibles côté coûts/observabilité, seulement les succès).
  const logFailure = async (errorMessage: string) => {
    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: "student_tutor_chat",
        provider: "gemini",
        duration_ms: Date.now() - startTime,
        status: "failed",
        error_message: errorMessage,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }
  };

  try {
    // rag_context/student_model_summary/tool_context : fournis par la Gateway (IA-007) quand elle est
    // l'appelante. profile_id/subject_id/class_node_id/lesson_id : ajoutés en 1.2.0 pour que l'app
    // élève, qui appelle en direct, obtienne le même enrichissement sans passer par la Gateway.
    const {
      message,
      subject_name,
      class_name,
      history,
      rag_context,
      student_model_summary,
      tool_context,
      profile_id,
      subject_id,
      class_node_id,
      lesson_id,
    } = await req.json();

    if (
      !message || typeof message !== "string" || message.trim().length === 0
    ) {
      return new Response(
        JSON.stringify({ error: "Message manquant." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!GEMINI_API_KEY) {
      // Jamais de réponse simulée en secours (voir 06_ai_pipeline.md) : une erreur claire côté
      // client vaut mieux qu'une fausse réussite.
      const errorMessage =
        "Le Tuteur Numérique n'est pas encore configuré (clé Gemini absente côté serveur).";
      await logFailure(errorMessage);
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ── Enrichissement calculé ici quand l'appelant ne l'a pas fourni (chemin app élève) ──────────
    let citations: Record<string, unknown>[] = [];
    let effectiveRagContext: string | null =
      typeof rag_context === "string" && rag_context.trim() ? rag_context : null;
    let effectiveMastery: string | null =
      typeof student_model_summary === "string" && student_model_summary.trim()
        ? student_model_summary
        : null;

    if (!effectiveRagContext && (subject_id || class_node_id)) {
      try {
        citations = await ragSearch(message, class_node_id ?? null, subject_id ?? null);
        if (citations.length > 0) {
          effectiveRagContext = citations
            .map((c) => `[${c.source_title ?? "Source"}] ${c.content}`)
            .join("\n\n");
        }
      } catch (ragErr) {
        // Le RAG est un bonus : son échec ne doit jamais priver l'élève d'une réponse.
        console.warn("RAG ignoré pour cet appel:", ragErr);
      }
    }

    if (!effectiveMastery && profile_id && subject_id) {
      const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
      if (jwt && await ownsProfile(jwt, String(profile_id))) {
        effectiveMastery = await masterySummary(String(profile_id), String(subject_id));
      } else {
        console.warn("profile_id non vérifié pour ce JWT — Student Model ignoré.");
      }
    }

    // Cache (ai_tutor_cache) — UNIQUEMENT pour une réponse non personnalisée. La version Python
    // (gateway/app/agents/tutor_agent.py) met en cache sur message|subject|lesson SANS profile_id
    // alors que le prompt contient le Student Model de l'élève : la réponse d'un élève peut donc
    // être resservie à un autre. Ce portage ne reproduit pas ce défaut — dès qu'une personnalisation
    // est injectée, la réponse n'est ni lue ni écrite dans le cache.
    const cacheable = effectiveMastery === null;
    const cacheKey = await sha256Hex(
      `${message.trim().toLowerCase()}|${subject_id ?? ""}|${lesson_id ?? ""}`,
    );

    if (cacheable) {
      try {
        const { data: cached } = await supabase
          .from("ai_tutor_cache")
          .select("reply,citations,hit_count")
          .eq("cache_key", cacheKey)
          .maybeSingle();
        if (cached?.reply) {
          await supabase
            .from("ai_tutor_cache")
            .update({
              hit_count: (cached.hit_count ?? 0) + 1,
              last_hit_at: new Date().toISOString(),
            })
            .eq("cache_key", cacheKey);
          return new Response(
            JSON.stringify({
              reply: cached.reply,
              citations: cached.citations ?? [],
              _request_id: requestId,
              _agent_version: AGENT_VERSION,
              _model: null,
              _route: "cache",
              _duration_ms: Date.now() - startTime,
            }),
            {
              status: 200,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            },
          );
        }
      } catch (cacheErr) {
        console.warn("Lecture de cache ignorée:", cacheErr);
      }
    }

    const systemPrompt =
      `Tu es un tuteur pédagogique bienveillant pour un(e) élève de ${
        class_name ?? "l'enseignement secondaire"
      }, en ${subject_name ?? "toutes matières"}.
Règles strictes :
- Maïeutique uniquement : guide l'élève pas à pas vers la réponse, ne donne JAMAIS directement la solution finale d'un exercice.
- Reste toujours dans le programme officiel de sa classe, sans bloquer totalement le hors-programme si l'élève insiste.
- Explique les erreurs (le "pourquoi"), jamais un simple "faux".
- Public mineur : langage toujours approprié, aucun sujet inapproprié, refuse poliment et détourne vers l'aide scolaire si l'élève dévie du cadre pédagogique.
- Réponses courtes et claires, en français, formules mathématiques entre $...$ si besoin.
- Tu es un outil d'aide, jamais une autorité absolue : encourage à vérifier avec son professeur en cas de doute.`;

    // IA-007 : contexte additif — soit fourni par la Gateway, soit calculé ci-dessus (1.2.0).
    const contextSections: string[] = [];
    if (effectiveRagContext) {
      contextSections.push(
        `Extraits de cours validés à utiliser en priorité pour les faits pédagogiques (cite la source entre crochets si tu t'en sers) :\n${effectiveRagContext}`,
      );
    }
    if (effectiveMastery) {
      contextSections.push(effectiveMastery);
    }
    if (typeof tool_context === "string" && tool_context.trim()) {
      contextSections.push(
        `Outil de calcul exact (fais confiance à ce résultat plutôt que de recalculer toi-même) :\n${tool_context}`,
      );
    }
    const fullSystemPrompt = contextSections.length > 0
      ? `${systemPrompt}\n\n${contextSections.join("\n\n")}`
      : systemPrompt;

    const contents = [];
    if (Array.isArray(history)) {
      for (const turn of history.slice(-10)) {
        contents.push({
          role: turn.sender === "ai" ? "model" : "user",
          parts: [{ text: String(turn.text ?? "") }],
        });
      }
    }
    contents.push({ role: "user", parts: [{ text: message }] });

    // §8 du CDC : "superpuissant et super gratuit" — modèle Gemini le plus capable du palier
    // gratuit, et un budget de sortie plus généreux pour des explications complètes plutôt que
    // tronquées. gemini-2.0-flash a été retiré (confirmé par l'erreur 404 de l'API elle-même, qui
    // recommandait explicitement gemini-3.6-flash) — vérifier périodiquement que ce nom de modèle
    // est toujours valide, Google en retire régulièrement.
    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: fullSystemPrompt }] },
          contents,
          // gemini-3.6-flash consomme des jetons de "réflexion" internes avant la réponse visible
          // (confirmé en test direct : ~140 jetons de réflexion pour "OK") — budget généreux pour
          // ne jamais tronquer une explication pédagogique complète derrière ce coût caché.
          generationConfig: { maxOutputTokens: 4096 },
        }),
      },
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error("Gemini API error:", geminiRes.status, errText);
      const errorMessage =
        "Le Tuteur Numérique est momentanément indisponible (quota atteint ou erreur du fournisseur).";
      await logFailure(errorMessage);
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const geminiData = await geminiRes.json();
    const reply = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const tokensUsed = geminiData.usageMetadata?.totalTokenCount ?? 0;

    if (!reply) {
      const errorMessage =
        "Le Tuteur Numérique n'a pas pu générer de réponse. Réessayez avec une question différente.";
      await logFailure(errorMessage);
      return new Response(
        JSON.stringify({ error: errorMessage, _request_id: requestId }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const durationMs = Date.now() - startTime;

    if (cacheable) {
      try {
        await supabase.from("ai_tutor_cache").insert({
          cache_key: cacheKey,
          subject_id: subject_id ?? null,
          class_node_id: class_node_id ?? null,
          query_text: message,
          reply,
          citations,
        });
      } catch (cacheErr) {
        console.warn("Écriture de cache ignorée:", cacheErr);
      }
    }

    try {
      await supabase.from("ai_agent_calls").insert({
        request_id: requestId,
        agent_type: "student_tutor_chat",
        provider: "gemini",
        model: MODEL,
        tokens_used: tokensUsed,
        cost_estimate: 0,
        duration_ms: durationMs,
        status: "success",
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(
      JSON.stringify({
        reply,
        // §10 : les citations remontent maintenant au client pour pouvoir être AFFICHÉES — elles
        // étaient calculées puis perdues (aucun chemin d'affichage côté élève, audit 2026-09-06).
        citations,
        _request_id: requestId,
        _agent_version: AGENT_VERSION,
        _model: MODEL,
        _route: "server",
        _duration_ms: durationMs,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("AI Tutor Chat Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
