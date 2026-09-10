// CurriculumMappingAgent (AIA-AGT-017, IA-008), porté depuis gateway/app/agents/curriculum_mapping.py
// Analyse le contenu d'un extrait/syllabus et suggère les rattachements curriculaires appropriés.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function stripAccents(str: string): string {
  return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

const STOPWORDS = new Set(
  [
    "les", "des", "une", "un", "le", "la", "de", "du", "et", "ou", "dans", "pour", "avec", "sur",
    "au", "aux", "est", "sont", "que", "qui", "ce", "ces", "cette", "son", "sa", "ses", "leur",
    "leurs", "etre", "avoir", "plus", "tout", "tous", "toute", "toutes", "comme", "sans", "vers",
    "cours", "chapitre", "lecon", "exercice", "partie", "section", "notion",
  ].map(stripAccents)
);

function extractSignificantWords(text: string): Set<string> {
  const normalized = stripAccents(text.toLowerCase());
  const matches = normalized.match(/[a-zA-Z]{4,}/g) || [];
  const words = new Set<string>();
  for (const w of matches) {
    if (!STOPWORDS.has(w)) {
      words.add(w);
    }
  }
  return words;
}

function keywordScore(inputWords: Set<string>, candidateText: string): number {
  const candidateWords = extractSignificantWords(candidateText);
  if (candidateWords.size === 0) return 0.0;
  let matches = 0;
  for (const w of candidateWords) {
    if (inputWords.has(w)) matches++;
  }
  return matches / candidateWords.size;
}

const CONFIDENCE_THRESHOLD = 0.3;
const AMBIGUITY_GAP = 0.1;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData } = await supabase.auth.getUser(jwt);

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
        JSON.stringify({ error: "Accès réservé aux administrateurs." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { text } = await req.json();
    if (!text || typeof text !== "string" || !text.trim()) {
      return new Response(
        JSON.stringify({
          chapter_candidates: [],
          skill_candidates: [],
          needs_human_review: true,
          reason: "Texte d'entrée vide.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const inputWords = extractSignificantWords(text);

    // 1. Récupération des chapitres avec libellés enrichis. Le nom de la classe vient de
    // academic_nodes via class_node_id (il n'existe pas de table academic_levels sur ce schéma).
    const { data: chapters } = await supabase
      .from("chapters")
      .select("id, title, subject_id, class_node_id, subjects(name), academic_nodes:class_node_id(name)")
      .limit(200);

    // 2. Récupération des compétences
    const { data: skills } = await supabase
      .from("skills")
      .select("id, name, subject_id, subjects(name)")
      .limit(200);

    const chapterCandidates: any[] = [];
    for (const ch of chapters ?? []) {
      const score = keywordScore(inputWords, ch.title);
      if (score > 0) {
        const subjectName = (ch.subjects as any)?.name ?? "Général";
        const levelName = (ch.academic_nodes as any)?.name ?? "";
        chapterCandidates.push({
          chapter_id: ch.id,
          title: ch.title,
          subject_id: ch.subject_id,
          subject_name: subjectName,
          class_node_id: ch.class_node_id,
          level_name: levelName,
          confidence: Math.round(score * 100) / 100,
          evidence: `Correspondance thématique avec l'intitulé « ${ch.title} » (${subjectName}${levelName ? ' • ' + levelName : ''}).`,
          method: "keyword",
        });
      }
    }

    chapterCandidates.sort((a, b) => b.confidence - a.confidence);

    const skillCandidates: any[] = [];
    for (const sk of skills ?? []) {
      const score = keywordScore(inputWords, sk.name);
      if (score > 0) {
        const subjectName = (sk.subjects as any)?.name ?? "Général";
        skillCandidates.push({
          skill_id: sk.id,
          name: sk.name,
          subject_id: sk.subject_id,
          subject_name: subjectName,
          confidence: Math.round(score * 100) / 100,
          evidence: `Alignement avec la compétence « ${sk.name} » (${subjectName}).`,
          method: "keyword",
        });
      }
    }

    skillCandidates.sort((a, b) => b.confidence - a.confidence);

    const top = chapterCandidates.length > 0 ? chapterCandidates[0].confidence : 0.0;
    const second = chapterCandidates.length > 1 ? chapterCandidates[1].confidence : 0.0;
    const needsHumanReview =
      chapterCandidates.length === 0 || top < CONFIDENCE_THRESHOLD || top - second < AMBIGUITY_GAP;

    return new Response(
      JSON.stringify({
        input_keywords_count: inputWords.size,
        chapter_candidates: chapterCandidates.slice(0, 5),
        skill_candidates: skillCandidates.slice(0, 5),
        needs_human_review: needsHumanReview,
        recommendation: needsHumanReview
          ? "Ambiguïté détectée ou confiance modérée : validation humaine recommandée."
          : "Correspondance nette identifiée : prêt pour rattachement automatique.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err?.message ?? "Erreur lors du mapping curriculaire." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
