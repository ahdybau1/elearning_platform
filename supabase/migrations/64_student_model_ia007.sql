-- IA-007 "Premier vertical slice" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) + U9 du cahier maître
-- ("Learning Orchestrator, Competency Graph et Student Model"), choix explicite du porteur de projet
-- de construire le Student Model complet plutôt qu'une version minimale ou un report.
--
-- U9 ne prescrit AUCUN schéma concret (juste la chaîne conceptuelle Competency Graph -> Student Model
-- -> Learning Orchestrator -> activité recommandée -> preuve d'apprentissage -> Mastery Engine). Le
-- schéma ci-dessous est donc une conception réelle, pas une transcription d'un schéma déjà spécifié
-- ailleurs — construite à partir de ce qui existe réellement en base (subjects/chapters/exercises).
--
-- Principe du cahier explicitement respecté : "Le succès dans un jeu ou une chanson ne suffit pas à
-- démontrer la maîtrise ; le transfert vers un exercice ou une évaluation indépendante doit être
-- mesuré." -> la maîtrise n'est JAMAIS stockée en dur, elle est recalculée à la demande depuis les
-- vraies tentatives d'exercices (exercise_attempts), pas depuis une estimation ou un score déclaratif.
--
-- Constat réel important (audit avant migration) : AUCUNE table de tentative d'exercice n'existait
-- avant cette migration (exercise_runner_screen.dart ne persistait rien) — exercise_attempts comble
-- ce vrai trou, indépendamment du Student Model. Constat réel #2 : les 6 seuls exercices existant en
-- base sont des fixtures de test CF-003 ("Énoncé généré factice... remplacez par un contenu réel avant
-- publication") — le Mastery Engine ci-dessous est donc réel et fonctionnel, mais n'aura de valeur
-- pédagogique qu'une fois du contenu réel publié (même situation que le RAG en IA-004 : pipeline réel,
-- corpus encore pauvre).

-- Competency Graph — nœuds (compétences), rattachées à une matière et optionnellement un
-- chapitre/niveau précis, sur le modèle de chapters.class_node_id.
CREATE TABLE IF NOT EXISTS skills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    class_node_id UUID REFERENCES academic_nodes(id) ON DELETE SET NULL,
    chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (subject_id, code)
);

-- Competency Graph — arêtes (prérequis). Une compétence peut avoir plusieurs prérequis.
CREATE TABLE IF NOT EXISTS skill_prerequisites (
    skill_id UUID NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    prerequisite_skill_id UUID NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    PRIMARY KEY (skill_id, prerequisite_skill_id),
    CHECK (skill_id <> prerequisite_skill_id)
);

-- Lien exercice -> compétence, curé (distinct de exercises.skills qui est un TEXT[] libre généré par
-- l'IA depuis CF-003, non fiabilisé en FK) : c'est ce lien qui sert d'instrument de mesure réel pour
-- le Mastery Engine.
CREATE TABLE IF NOT EXISTS exercise_skills (
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    skill_id UUID NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    PRIMARY KEY (exercise_id, skill_id)
);

-- Preuve d'apprentissage : la vraie persistance des tentatives d'exercices, qui n'existait pas du
-- tout avant cette migration. is_correct reste NULL pour les formats sans correction automatique
-- (réponse rédigée, auto-évaluée par l'élève) — seul le QCM a un signal de correction déterministe
-- aujourd'hui.
CREATE TABLE IF NOT EXISTS exercise_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    is_correct BOOLEAN,
    submitted_answer JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exercise_attempts_profile ON exercise_attempts (profile_id, created_at DESC);

-- Cache de réponses TutorAgent (IA-007, "Modèle. Cache/déterministe si possible" — §AIA-AGT-001).
-- Purement interne à la Gateway (service_role) : aucune policy publique, RLS activée sans exception
-- pour bloquer tout accès direct depuis un client authentifié.
CREATE TABLE IF NOT EXISTS ai_tutor_cache (
    cache_key TEXT PRIMARY KEY,
    subject_id UUID REFERENCES subjects(id),
    class_node_id UUID REFERENCES academic_nodes(id),
    query_text TEXT NOT NULL,
    reply TEXT NOT NULL,
    citations JSONB NOT NULL DEFAULT '[]',
    hit_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_hit_at TIMESTAMPTZ
);

ALTER TABLE skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE skill_prerequisites ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_tutor_cache ENABLE ROW LEVEL SECURITY;

-- Competency Graph : catalogue public en lecture (même logique que ai_policies/access_matrix),
-- écriture réservée à l'équipe pédagogique/admin.
DROP POLICY IF EXISTS skills_select ON skills;
CREATE POLICY skills_select ON skills FOR SELECT USING (true);
DROP POLICY IF EXISTS skills_write ON skills;
CREATE POLICY skills_write ON skills FOR ALL USING (has_admin_role('super_admin', 'admin_contenu')) WITH CHECK (has_admin_role('super_admin', 'admin_contenu'));

DROP POLICY IF EXISTS skill_prerequisites_select ON skill_prerequisites;
CREATE POLICY skill_prerequisites_select ON skill_prerequisites FOR SELECT USING (true);
DROP POLICY IF EXISTS skill_prerequisites_write ON skill_prerequisites;
CREATE POLICY skill_prerequisites_write ON skill_prerequisites FOR ALL USING (has_admin_role('super_admin', 'admin_contenu')) WITH CHECK (has_admin_role('super_admin', 'admin_contenu'));

DROP POLICY IF EXISTS exercise_skills_select ON exercise_skills;
CREATE POLICY exercise_skills_select ON exercise_skills FOR SELECT USING (true);
DROP POLICY IF EXISTS exercise_skills_write ON exercise_skills;
CREATE POLICY exercise_skills_write ON exercise_skills FOR ALL USING (has_admin_role('super_admin', 'admin_contenu')) WITH CHECK (has_admin_role('super_admin', 'admin_contenu'));

-- Tentatives : l'élève écrit/lit les siennes (append-only côté application — pas de policy
-- UPDATE/DELETE, une tentative ne se corrige pas rétroactivement), l'admin lit tout.
DROP POLICY IF EXISTS exercise_attempts_select ON exercise_attempts;
CREATE POLICY exercise_attempts_select ON exercise_attempts FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS exercise_attempts_insert ON exercise_attempts;
CREATE POLICY exercise_attempts_insert ON exercise_attempts FOR INSERT WITH CHECK (owns_profile(profile_id));

-- ai_tutor_cache : aucune policy = inaccessible à tout rôle sauf service_role (qui bypass RLS), par
-- construction. Uniquement lu/écrit par la Gateway (gateway/app/agents/tutor_agent.py).

-- Fonction SECURITY DEFINER (même style que match_rag_chunks, IA-004) : agrège les tentatives réelles
-- en maîtrise par compétence, à la demande, jamais stockée/désynchronisable.
--
-- Pas de vérification owns_profile/is_admin_user ICI, volontairement — même trust model que
-- match_rag_chunks (IA-004) : cette RPC est appelée uniquement côté serveur par la Gateway via la clé
-- service_role (gateway/app/student_model/mastery.py), qui n'a pas de contexte auth.uid() (les appels
-- service_role via PostgREST ne portent aucune revendication JWT, donc owns_profile()/is_admin_user()
-- y renverraient toujours faux — ça avait été vérifié pour match_rag_chunks lors d'IA-004). L'accès
-- réel est autorisé une seule fois, en amont, côté Python : gateway/app/auth.py
-- `verify_profile_access()` vérifie que le profile_id demandé appartient bien au compte authentifié
-- (ou que l'appelant est admin) avant que cette fonction ne soit jamais invoquée.
CREATE OR REPLACE FUNCTION get_student_skill_mastery(p_profile_id UUID, p_subject_id UUID DEFAULT NULL)
RETURNS TABLE (
    skill_id UUID,
    skill_name TEXT,
    attempts_count BIGINT,
    correct_count BIGINT,
    mastery_level NUMERIC,
    last_attempt_at TIMESTAMPTZ
) AS $$
    SELECT es.skill_id, sk.name,
           COUNT(*) AS attempts_count,
           COUNT(*) FILTER (WHERE ea.is_correct) AS correct_count,
           ROUND(COUNT(*) FILTER (WHERE ea.is_correct)::numeric / NULLIF(COUNT(*), 0), 3) AS mastery_level,
           MAX(ea.created_at) AS last_attempt_at
    FROM exercise_attempts ea
    JOIN exercise_skills es ON es.exercise_id = ea.exercise_id
    JOIN skills sk ON sk.id = es.skill_id
    WHERE ea.profile_id = p_profile_id
      AND (p_subject_id IS NULL OR sk.subject_id = p_subject_id)
    GROUP BY es.skill_id, sk.name;
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

NOTIFY pgrst, 'reload schema';
