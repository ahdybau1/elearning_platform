// PedagogicalValidationAgent (AIA-AGT-024, IA-008), porté depuis gateway/app/agents/pedagogical_validation.py
// Précontrôle automatisé non bloquant pour assister la revue humaine dans validation_queue.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUBSTANTIVE_TYPES = new Set(["definition", "theoreme", "methode", "summary_card", "formule"]);
const MOCK_MARKERS = ["factice", "remplacez par un contenu réel", "mock", "lorem ipsum"];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData } = await supabase.auth.getUser(jwt);

    // Vérification droits administrateur ou enseignant
    const { data: admin } = userData?.user?.id
      ? await supabase
          .from("admin_users")
          .select("role")
          .eq("auth_user_id", userData.user.id)
          .eq("is_active", true)
          .maybeSingle()
      : { data: null };

    if (!admin) {
      return new Response(
        JSON.stringify({ error: "Accès réservé aux administrateurs et modérateurs pédagogiques." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { lesson_id } = await req.json();
    if (!lesson_id) {
      return new Response(
        JSON.stringify({ error: "Paramètre 'lesson_id' manquant." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Récupération de la leçon
    const { data: lesson, error: lessonErr } = await supabase
      .from("lessons")
      .select("id,title,content_json,is_published,is_active,chapter_id")
      .eq("id", lesson_id)
      .maybeSingle();

    if (lessonErr || !lesson) {
      return new Response(
        JSON.stringify({
          checklist: [],
          errors: [`Leçon introuvable : ${lesson_id}`],
          warnings: [],
          blocking_issues: [`Leçon introuvable : ${lesson_id}`],
          confidence: 0.0,
          recommendation: "Impossible de valider : ressource inexistante.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const contentJson = (lesson.content_json as Record<string, any>) || {};
    let blocks: any[] = [];
    if (Array.isArray(contentJson.blocks) && contentJson.blocks.length > 0) {
      blocks = contentJson.blocks;
    } else if (
      contentJson.ai_structured &&
      Array.isArray(contentJson.ai_structured.sections)
    ) {
      blocks = contentJson.ai_structured.sections;
    }

    const errors: string[] = [];
    const warnings: string[] = [];

    // 1. Contrôle structure
    if (blocks.length === 0) {
      errors.push("Aucun bloc de contenu structuré trouvé (ni `blocks`, ni `ai_structured.sections`).");
    } else {
      const types = new Set(blocks.map((b) => b?.type));
      let hasSubstantive = false;
      for (const t of types) {
        if (SUBSTANTIVE_TYPES.has(t)) {
          hasSubstantive = true;
          break;
        }
      }
      if (!hasSubstantive) {
        warnings.push("Aucun bloc substantiel majeur (définition, théorème, méthode, fiche synthèse) — leçon peut-être trop brève.");
      }

      for (let i = 0; i < blocks.length; i++) {
        const b = blocks[i];
        const bodyText = (b?.body ?? "").toString().trim();
        const headingText = (b?.heading ?? "").toString().trim();
        if (!bodyText && !headingText && b?.type !== "summary_card") {
          errors.push(`Bloc #${i + 1} (type=${b?.type ?? "inconnu"}) a un corps et titre vides.`);
        }
      }
    }

    // 2. Détection de mock / contenu factice
    if (contentJson.ai_structured && contentJson.ai_structured._mock) {
      warnings.push("Contenu marqué comme MOCK de développement (`_mock: true`) — ne doit pas être publié tel quel.");
    }
    for (const b of blocks) {
      const bodyLower = (b?.body ?? "").toString().toLowerCase();
      const headingLower = (b?.heading ?? "").toString().toLowerCase();
      if (MOCK_MARKERS.some((m) => bodyLower.includes(m) || headingLower.includes(m))) {
        warnings.push("Un bloc contient un marqueur de contenu factice/placeholder — probable contenu de test.");
        break;
      }
    }

    // 3. Contrôle des formules LaTeX
    let totalFormulas = 0;
    for (const b of blocks) {
      const formList = b?.formulas ?? b?.latex_formulas ?? [];
      if (Array.isArray(formList)) {
        totalFormulas += formList.length;
      }
    }

    // 4. Contrôle rattachement curriculaire
    if (!lesson.chapter_id) {
      errors.push("Leçon sans `chapter_id` — aucun rattachement curriculaire.");
    } else {
      const { data: chapter } = await supabase
        .from("chapters")
        .select("id,subject_id,class_node_id,title")
        .eq("id", lesson.chapter_id)
        .maybeSingle();

      if (!chapter) {
        errors.push("`chapter_id` référence un chapitre introuvable en base de données.");
      } else if (!chapter.subject_id || !chapter.class_node_id) {
        warnings.push("Chapitre rattaché mais incomplet (matière ou niveau de classe manquant).");
      }
    }

    const blockingIssues = [...errors];
    if (lesson.is_published && warnings.some((w) => w.includes("MOCK") || w.includes("factice"))) {
      blockingIssues.push("Contenu factice détecté sur une leçon DÉJÀ PUBLIÉE — revue urgente requise.");
    }

    const checklist = [
      { check: "structure_blocs", passed: errors.filter((e) => e.includes("bloc")).length === 0, label: "Structure des Blocs" },
      { check: "contenu_non_factice", passed: warnings.filter((w) => w.includes("factice") || w.includes("MOCK")).length === 0, label: "Contenu Réel & Non Factice" },
      { check: "rattachement_curriculaire", passed: errors.filter((e) => e.includes("chapter_id") || e.includes("chapitre")).length === 0, label: "Rattachement Curriculaire" },
    ];

    const passedCount = checklist.filter((c) => c.passed).length;
    const confidence = checklist.length > 0 ? Math.round((passedCount / checklist.length) * 100) / 100 : 0.0;

    let recommendation = "Conforme : prête pour validation et publication humaine.";
    if (blockingIssues.length > 0) {
      recommendation = "Non conforme : des corrections bloquantes sont nécessaires avant publication.";
    } else if (warnings.length > 0) {
      recommendation = "Conforme avec réserves : points d'attention à vérifier avant mise en ligne.";
    }

    return new Response(
      JSON.stringify({
        lesson_id: lesson.id,
        lesson_title: lesson.title,
        checklist,
        errors,
        warnings,
        blocking_issues: blockingIssues,
        confidence,
        recommendation,
        total_blocks: blocks.length,
        total_formulas: totalFormulas,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err?.message ?? "Erreur interne lors de la pré-validation." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
