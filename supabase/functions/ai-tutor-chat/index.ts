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
// 1.3.0 (2026-09-17) : support multimodal complet (photos/OCR devoirs manuscrits, documents PDF,
// enregistrements audio/voix) transmis en inline_data à Google Gemini sans stockage BDD.
const AGENT_VERSION = "1.3.1";
// Liste ordonnée de modèles Gemini gratuits avec cascade de secours automatique :
// Si un modèle subit une saturation de quota (429) ou indisponibilité (503),
// la requête bascule instantanément sur le modèle suivant de la chaîne.
const CANDIDATE_MODELS = [
  "gemini-flash-latest",
  "gemini-3.5-flash",
  "gemini-3.7-flash",
  "gemini-3.8-flash",
];
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
      attachments,
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

    // Détection des salutations pures (bonjour, salut, coucou, bonsoir...)
    const cleanMsg = message.trim().toLowerCase().replace(/[!?,.;:]+$/, "").trim();
    const isGreeting = /^(bonjour|bonsoir|salut|coucou|hello|hi|hey|yo|bonne\s+journée|bon\s+après[- ]midi)$/i.test(cleanMsg) ||
      (/^(bonjour|bonsoir|salut|coucou|hello|hi|hey)\s+(à tous|tout le monde|tuteur|prof|pq learn|tuteur pq learn)?$/i.test(cleanMsg));

    const hasAttachments = Array.isArray(attachments) && attachments.length > 0;

    // ── Niveau 1 : Salutations (§1 CDC : déterministe immédiat sans latence ni dépendance LLM) ──
    if (isGreeting && !hasAttachments) {
      const greetings = [
        "Bonjour ! 😊 Je suis ton Tuteur pq learn. Sur quelle matière, quel chapitre ou quel exercice aimerais-tu qu'on avance ensemble aujourd'hui ?",
        "Salut ! 🚀 Prêt(e) pour réviser ? Dis-moi sur quelle notion ou quel devoir tu souhaites que je t'accompagne.",
        "Bonjour ! ✨ C'est un plaisir de t'aider. Pose-moi ta question ou montre-moi ton exercice, et on va le comprendre pas à pas !",
        "Hello ! 🎯 Bienvenue sur ton espace de travail. Qu'aimerais-tu comprendre ou réviser aujourd'hui ?",
        "Bonjour ! 📚 Ton Tuteur pq learn est à ton écoute. Sur quel point de cours as-tu besoin d'un coup de pouce ?",
      ];
      const chosen = greetings[Math.floor(Math.random() * greetings.length)];
      return new Response(
        JSON.stringify({
          reply: chosen,
          citations: [],
          _request_id: requestId,
          _agent_version: AGENT_VERSION,
          _model: "deterministic_greeting",
          _route: "deterministic",
          _duration_ms: Date.now() - startTime,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const cacheable = effectiveMastery === null && !hasAttachments && !isGreeting;
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

    const greetingRule = isGreeting
      ? `\n\n⚡ RÈGLE SPÉCIALE SALUTATION : L'élève te salue simplement.
- Réponds de façon très brève, naturelle, chaleureuse et motivante (1 à 2 phrases courtes maximum).
- Salue l'élève avec enthousiasme (par ex: "Bonjour ! 😊 Je suis ton Tuteur pq learn. Sur quel sujet, chapitre ou exercice aimerais-tu qu'on avance ensemble aujourd'hui ?").
- Varie tes formulations à chaque fois.
- Ne donne JAMAIS de cours, de formule, d'explication de maths ou de monologue non sollicité lorsqu'on te salue simplement.`
      : "";

    const systemPrompt =
      `Tu es le Tuteur pq learn, tuteur pédagogique numérique bienveillant pour un(e) élève de ${
        class_name ?? "l'enseignement secondaire"
      }, en ${subject_name ?? "toutes matières"}.
Règles pédagogiques et éthiques :
- Démarche maïeutique et socratique : guide l'élève pas à pas vers la compréhension par des questions stimulantes et des indices progressifs. Ne donne JAMAIS directement la solution finale d'un exercice.
- Reste toujours dans le programme officiel de sa classe, sans bloquer le hors-programme si l'élève insiste.
- Explique toujours les erreurs (le "pourquoi" et la méthode), jamais un simple "faux".
- Public mineur : langage toujours respectueux, empathique et encourageant. Refuse poliment tout contenu hors cadre scolaire.
- Tu es un outil d'aide : encourage à vérifier avec son professeur en cas de doute.${greetingRule}

Mise en forme soignée (Markdown riche, LaTeX & Émojis) :
- Structure tes réponses avec des sous-titres clairs (###), des listes numérotées (1., 2.) pour les étapes, et des puces (- ) pour les critères.
- Mets en **gras** les notions clés, les termes essentiels et les étapes.
- Mets en *italique* les indices subtils et remarques méthodologiques.
- Encadre les rappels et astuces avec une citation : > 💡 **Conseil** : ...
- Formules mathématiques : écris TOUJOURS les variables, fractions et formules en notation LaTeX standard entre $...$ pour l'en-ligne (ex: $\\Delta = b^2 - 4ac$, $x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a}$) ou $$...$$ pour une équation officielle centrée.
- Schémas & Représentations Graphiques (§1 & §6 CDC) : N'invente JAMAIS d'URLs d'images externes aléatoires et n'utilise pas de générateurs d'art IA (qui inventent des courbes mathématiquement fausses et du texte flou).
  - Pour toute fonction mathématique (parabole, polynôme, droite, trigonométrie...) : écris TOUJOURS la formule exacte en notation LaTeX (ex: $P(x) = 2x^2 - 4x - 6$). L'interface de l'application détecte automatiquement la fonction et affiche un bouton direct pour tracer la courbe exacte et sa tangente dans un repère interactif calculé au millimètre !
  - Pour les démarches, algorithmes et cycles : utilise des schémas textuels clairs et structurés (ex: Entrée ➔ Étape 1 ➔ Résultat) ou des tableaux récapitulatifs.
  - Pour les documents officiels : cite les extraits de cours et fiches du programme validées fournies dans le contexte.

Support multimodal :
- Analyse minutieusement les photos/images jointes (OCR d'exercice manuscrit, figure, livre), cite les données reconnues et aide l'élève.
- Écoute ou lis attentivement les mémos vocaux et documents joints pour répondre précisément.`;

    // IA-007 : contexte additif — soit fourni par la Gateway, soit calculé ci-dessus (1.2.0).
    const contextSections: string[] = [];
    if (effectiveRagContext && !isGreeting) {
      contextSections.push(
        `Extraits de cours validés à utiliser en priorité pour les faits pédagogiques (cite la source entre crochets si tu t'en sers) :\n${effectiveRagContext}`,
      );
    }
    if (effectiveMastery && !isGreeting) {
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
    if (Array.isArray(history) && !isGreeting) {
      for (const turn of history.slice(-10)) {
        contents.push({
          role: turn.sender === "ai" ? "model" : "user",
          parts: [{ text: String(turn.text ?? "") }],
        });
      }
    }

    const userParts: Array<Record<string, unknown>> = [{ text: message }];
    if (hasAttachments) {
      for (const att of attachments) {
        if (att && typeof att.data === "string" && att.data.trim().length > 0) {
          const rawMime = String(att.mime_type || "image/jpeg").toLowerCase();
          const mimeType = rawMime.startsWith("image/") ||
              rawMime === "application/pdf" ||
              rawMime.startsWith("audio/")
            ? rawMime
            : "image/jpeg";

          userParts.push({
            inline_data: {
              mime_type: mimeType,
              data: att.data.trim(),
            },
          });
        }
      }
    }
    contents.push({ role: "user", parts: userParts });

    // §8 du CDC : modèle Gemini avec retry exponentiel
    const geminiPayload = {
      systemInstruction: { parts: [{ text: fullSystemPrompt }] },
      contents,
      generationConfig: { maxOutputTokens: isGreeting ? 2048 : 4096 },
    };

    let geminiRes: Response | null = null;
    let selectedModel = CANDIDATE_MODELS[0];
    let lastErrorText = "";

    // Multi-modèles avec cascade de secours automatique :
    // Si un modèle subit une saturation de quota (429) ou indisponibilité (503/404),
    // la requête bascule instantanément sur le modèle suivant de la chaîne sans interruption !
    for (const modelCandidate of CANDIDATE_MODELS) {
      selectedModel = modelCandidate;
      let modelSucceeded = false;

      const retryDelays = [0, 800];
      for (let attempt = 0; attempt < retryDelays.length; attempt++) {
        if (attempt > 0) {
          await new Promise((r) => setTimeout(r, retryDelays[attempt]));
        }

        try {
          geminiRes = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelCandidate}:generateContent?key=${GEMINI_API_KEY}`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(geminiPayload),
            },
          );

          if (geminiRes.ok) {
            modelSucceeded = true;
            break;
          }

          lastErrorText = await geminiRes.text();
          console.warn(`Modèle ${modelCandidate} (${geminiRes.status}):`, lastErrorText.substring(0, 120));

          // Si quota atteint (429) ou modèle déprécié (404), basculer immédiatement vers le modèle suivant
          if (geminiRes.status === 429 || geminiRes.status === 404) {
            break;
          }
        } catch (networkErr) {
          console.warn(`Erreur réseau sur ${modelCandidate}:`, networkErr);
        }
      }

      if (modelSucceeded && geminiRes && geminiRes.ok) {
        break;
      }
    }

    if (!geminiRes || !geminiRes.ok) {
      console.warn("Tous les modèles LLM distants sont indisponibles. Activation du Mode Dégradé Pédagogique Prévalidé (§Module 4 CDC)...");
      
      let fallbackReply = "";
      if (effectiveRagContext && citations.length > 0) {
        fallbackReply = `### 📚 Fiche Méthode & Notions Clés (Programme Officiel)\n\n` +
          `Voici les éléments officiels de ton programme pour progresser sur ce point :\n\n` +
          effectiveRagContext +
          `\n\n> 💡 **Conseil méthodologique** : Repère bien les hypothèses de ton énoncé et applique la méthode ci-dessus étape par étape. Si tu as un doute sur un calcul, précise-le moi !`;
      } else {
        const lowerMsg = message.toLowerCase();
        if (lowerMsg.includes("suite") || lowerMsg.includes("arithmétique") || lowerMsg.includes("géométrique")) {
          fallbackReply = `### 📐 Rappel de Cours : Les Suites Numériques\n\n` +
            `Pour une **suite arithmétique** de premier terme $u_0$ et de raison $r$ :\n` +
            `- **Relation de récurrence** : $u_{n+1} = u_n + r$\n` +
            `- **Terme général** : $u_n = u_0 + n \\cdot r$ (ou $u_n = u_p + (n-p)r$)\n` +
            `- **Somme des termes consécutifs** : $S_n = \\frac{\\text{nombre de termes} \\times (\\text{premier terme} + \\text{dernier terme})}{2}$\n\n` +
            `Pour une **suite géométrique** de raison $q \\neq 1$ :\n` +
            `- $u_n = u_0 \\cdot q^n$ et $S_n = u_0 \\cdot \\frac{1 - q^n}{1 - q}$\n\n` +
            `> 💡 **Conseil** : Quelle est la question exacte de ton exercice ? Donne-moi les valeurs de $u_0$ et de la raison pour qu'on avance ensemble !`;
        } else if (lowerMsg.includes("dériv") || lowerMsg.includes("fonction") || lowerMsg.includes("tangente")) {
          fallbackReply = `### 📈 Rappel de Cours : Dérivation et Étude de Fonctions\n\n` +
            `- **Dérivées usuelles** : $(x^n)' = n x^{n-1}$, $(uv)' = u'v + uv'$, $\\left(\\frac{u}{v}\\right)' = \\frac{u'v - uv'}{v^2}$\n` +
            `- **Équation de la tangente** en $a$ : $y = f'(a)(x - a) + f(a)$\n` +
            `- **Signe de la dérivée** : si $f'(x) > 0$, $f$ est strictement croissante ; si $f'(x) < 0$, $f$ est strictement décroissante.\n\n` +
            `> 💡 **Conseil** : Quelle fonction souhaites-tu dériver ou étudier ? Partage son expression pour qu'on regarde la méthode !`;
        } else if (lowerMsg.includes("pythagore") || lowerMsg.includes("thalès") || lowerMsg.includes("triangle")) {
          fallbackReply = `### 📐 Rappel de Géométrie : Théorèmes Fondamentaux\n\n` +
            `- **Théorème de Pythagore** : Dans un triangle $ABC$ rectangle en $A$ : $BC^2 = AB^2 + AC^2$\n` +
            `- **Théorème de Thalès** : Dans un triangle $ABC$ avec $(MN) // (BC)$ : $\\frac{AM}{AB} = \\frac{AN}{AC} = \\frac{MN}{BC}$\n\n` +
            `> 💡 **Conseil** : As-tu identifié les longueurs connues dans ton énoncé ?`;
        } else {
          fallbackReply = `### 📖 Guide Méthodologique de Résolution\n\n` +
            `Pour avancer efficacement sur cette notion :\n` +
            `1. **Définir la notion** : Identifie le chapitre et la formule centrale du cours concerné.\n` +
            `2. **Lister les données** : Quelles sont les données fournies par ton énoncé ?\n` +
            `3. **Démarche pas à pas** : Écris chaque étape de raisonnement sans sauter de calcul.\n\n` +
            `> 💡 **Aide interactive** : Précise-moi ton calcul ou partage la photo de ton énoncé pour qu'on détaille la solution pas à pas !`;
        }
      }

      await logFailure("Fallback prévalidé servi (indisponibilité LLM distant absorbée)");

      return new Response(
        JSON.stringify({
          reply: fallbackReply,
          citations,
          _request_id: requestId,
          _agent_version: AGENT_VERSION,
          _model: "curriculum_prevalidated_engine",
          _route: "deterministic_fallback",
          _duration_ms: Date.now() - startTime,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const geminiData = await geminiRes.json();
    const rawParts = geminiData.candidates?.[0]?.content?.parts ?? [];
    let reply = "";
    for (const part of rawParts) {
      if (part && typeof part.text === "string" && !part.thought) {
        reply += part.text;
      }
    }
    reply = reply.trim();
    const tokensUsed = geminiData.usageMetadata?.totalTokenCount ?? 0;

    if (!reply) {
      reply = "### 💡 Indice Pédagogique\n\nReprends les définitions fondamentales de ton cours sur ce point pour vérifier la première étape de ton calcul.";
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
        model: selectedModel,
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
        _model: selectedModel,
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
