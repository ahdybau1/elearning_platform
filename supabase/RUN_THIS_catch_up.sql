-- ============================================================================
-- FICHIER DE RATTRAPAGE — à coller une seule fois dans le SQL Editor de Supabase.
-- Regroupe les migrations 12 à 17 (tout ce qui a été ajouté dans cette session : fusion de
-- classes, versioning des leçons, upload pour l'intro de chapitre, cloisonnement chapitre↔classe,
-- archivage des exercices, cloisonnement chapitre/exercice↔classe et trimestre).
--
-- La migration 17 RÉÉCRIT merge_academic_class_nodes (12) et duplicate_chapter_to_class (15) —
-- comme ce sont des CREATE OR REPLACE FUNCTION, coller ce fichier dans l'ordre remplace bien les
-- anciennes versions par les nouvelles ; aucune action supplémentaire nécessaire.
--
-- Sûr à exécuter plusieurs fois (idempotent) : n'écrase aucune donnée existante, ne duplique rien.
-- Contrairement à reset_project_schema.sql, ce fichier NE fait PAS de DROP SCHEMA — tes données
-- actuelles (comptes, contenus déjà créés) sont conservées telles quelles.
--
-- Ce fichier ne couvre QUE le SQL (tables, colonnes, policies, fonctions RPC). Les Edge Functions
-- (ai-course-structuring, ai-exercise-generation) ne sont pas du SQL et ne peuvent pas être collées
-- ici : elles se déploient avec la Supabase CLI. Voir les commandes tout en bas de ce fichier.
-- ============================================================================

-- ── 12_merge_class_nodes.sql ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION merge_academic_class_nodes(
    p_source_id UUID,
    p_target_id UUID,
    p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_source_type TEXT;
    v_target_type TEXT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    IF p_source_id = p_target_id THEN
        RAISE EXCEPTION 'Impossible de fusionner un nœud avec lui-même';
    END IF;

    SELECT node_type INTO v_source_type FROM academic_nodes WHERE id = p_source_id;
    SELECT node_type INTO v_target_type FROM academic_nodes WHERE id = p_target_id;

    IF v_source_type IS NULL OR v_target_type IS NULL THEN
        RAISE EXCEPTION 'Nœud source ou cible introuvable';
    END IF;

    IF v_source_type != v_target_type THEN
        RAISE EXCEPTION 'Les deux nœuds doivent être du même type (% != %)', v_source_type, v_target_type;
    END IF;

    IF v_source_type NOT IN ('class', 'series') THEN
        RAISE EXCEPTION 'Seules les Classes et Séries peuvent être fusionnées';
    END IF;

    UPDATE profiles SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    DELETE FROM subject_class_links scl
    WHERE scl.class_node_id = p_source_id
      AND EXISTS (
        SELECT 1 FROM subject_class_links t
        WHERE t.class_node_id = p_target_id AND t.subject_id = scl.subject_id
      );
    UPDATE subject_class_links SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE subscription_tiers SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE official_exams SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE establishment_papers SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE forum_threads SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE whatsapp_communities SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE events SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE announcements SET target_class_id = p_target_id WHERE target_class_id = p_source_id;

    UPDATE shop_documents SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE academic_nodes SET parent_id = p_target_id WHERE parent_id = p_source_id;

    UPDATE academic_nodes SET is_active = FALSE, updated_at = NOW() WHERE id = p_source_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        p_admin_id, 'merge', 'academic_node', p_target_id,
        jsonb_build_object('source_id', p_source_id, 'node_type', v_source_type),
        jsonb_build_object('target_id', p_target_id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION merge_academic_class_nodes(UUID, UUID, UUID) TO authenticated;

-- ── 13_lessons_polish.sql ─────────────────────────────────────────────────
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS lesson_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    content_json JSONB NOT NULL,
    published_by UUID NOT NULL,
    published_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lesson_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_versions_admin_all ON lesson_versions;
CREATE POLICY lesson_versions_admin_all ON lesson_versions FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS lessons_select ON lessons;
CREATE POLICY lessons_select ON lessons FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND is_active = true
        AND (min_subscription_tier = 'gratuit' OR current_user_has_feature_access('courses'))
    )
);

-- ── 14_chapter_intro_media.sql ────────────────────────────────────────────
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS intro_media_json JSONB DEFAULT '[]'::jsonb;

-- ── 15_chapters_class_scoping.sql ─────────────────────────────────────────
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_chapters_class_node_id ON chapters(class_node_id);

CREATE OR REPLACE FUNCTION duplicate_chapter_to_class(
    p_chapter_id UUID,
    p_target_class_node_id UUID,
    p_admin_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_new_chapter_id UUID;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    INSERT INTO chapters (subject_id, term_id, class_node_id, title, introduction, intro_media_json, display_order, is_active)
    SELECT subject_id, term_id, p_target_class_node_id, title, introduction, intro_media_json, display_order, is_active
    FROM chapters WHERE id = p_chapter_id
    RETURNING id INTO v_new_chapter_id;

    INSERT INTO lessons (chapter_id, title, content_json, display_order, is_published, is_active, min_subscription_tier)
    SELECT v_new_chapter_id, title, content_json, display_order, FALSE, is_active, min_subscription_tier
    FROM lessons WHERE chapter_id = p_chapter_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        p_admin_id, 'duplicate_to_class', 'chapter', v_new_chapter_id,
        jsonb_build_object('source_chapter_id', p_chapter_id),
        jsonb_build_object('target_class_node_id', p_target_class_node_id)
    );

    RETURN v_new_chapter_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION duplicate_chapter_to_class(UUID, UUID, UUID) TO authenticated;

-- ── 16_exercises_archive.sql ──────────────────────────────────────────────
-- Archivage des exercices (cohérent avec lessons.is_active / chapters.is_active). Un exercice
-- archivé ne doit plus être visible côté élève même s'il était publié au moment de l'archivage.
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

DROP POLICY IF EXISTS exercises_select ON exercises;
CREATE POLICY exercises_select ON exercises FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND is_active = true
        AND (
            min_subscription_tier = 'gratuit'
            OR (type = 'entraînement' AND current_user_has_feature_access('exercises_training'))
            OR (type = 'évaluation' AND current_user_has_feature_access('exercises_evaluation'))
        )
    )
);

-- ── 17_exercises_class_scoping.sql ────────────────────────────────────────
-- Les exercices "Niveau 3 : indépendant, type examen" (chapter_id ET lesson_id null) n'avaient
-- aucun moyen d'indiquer la classe/série ciblée — trou fonctionnel réel pour une banque
-- d'exercices type examen. On ajoute class_node_id/term_id à exercises, mêmes colonnes et même
-- esprit que chapters (migration 15_chapters_class_scoping.sql).
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS term_id UUID REFERENCES terms(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_exercises_class_node_id ON exercises(class_node_id);

-- Backfill : les exercices Niveau 1/2 héritent de la classe/trimestre de leur chapitre parent
-- (directement, ou via leur leçon). Les Niveau 3 existants (chapter_id ET lesson_id null)
-- restent volontairement class_node_id/term_id NULL — impossible de deviner leur classe cible
-- sans risque de se tromper ; ils seront traités comme "Non classé" côté UI (badge rouge, filtre
-- dédié) pour un rattrapage manuel et délibéré par l'admin, jamais une valeur par défaut devinée.
UPDATE exercises e SET class_node_id = c.class_node_id, term_id = c.term_id
FROM chapters c WHERE e.chapter_id = c.id;

UPDATE exercises e SET class_node_id = c.class_node_id, term_id = c.term_id
FROM lessons l JOIN chapters c ON c.id = l.chapter_id
WHERE e.lesson_id = l.id;

-- Synchronisation automatique : dérive class_node_id/term_id depuis le chapitre parent à chaque
-- INSERT/UPDATE d'un exercice Niveau 1/2. Pour un exercice Niveau 3 (chapter_id ET lesson_id
-- restent null), on ne touche pas les valeurs — l'admin les fournit explicitement via l'UI.
-- Point unique de vérité plutôt que de dupliquer la règle dans chaque endroit du code Dart qui
-- crée/modifie un exercice (modale manuelle, modale IA, futurs appelants).
CREATE OR REPLACE FUNCTION sync_exercise_class_scope() RETURNS TRIGGER AS $$
DECLARE
    v_class_node_id UUID;
    v_term_id UUID;
BEGIN
    IF NEW.chapter_id IS NOT NULL THEN
        SELECT class_node_id, term_id INTO v_class_node_id, v_term_id
        FROM chapters WHERE id = NEW.chapter_id;
        NEW.class_node_id := v_class_node_id;
        NEW.term_id := v_term_id;
    ELSIF NEW.lesson_id IS NOT NULL THEN
        SELECT c.class_node_id, c.term_id INTO v_class_node_id, v_term_id
        FROM lessons l JOIN chapters c ON c.id = l.chapter_id WHERE l.id = NEW.lesson_id;
        NEW.class_node_id := v_class_node_id;
        NEW.term_id := v_term_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_exercise_class_scope ON exercises;
CREATE TRIGGER trg_sync_exercise_class_scope
BEFORE INSERT OR UPDATE OF chapter_id, lesson_id ON exercises
FOR EACH ROW EXECUTE FUNCTION sync_exercise_class_scope();

-- Propage un changement de classe/trimestre du chapitre vers tous ses exercices descendants
-- (directs via chapter_id, indirects via lesson_id -> lessons.chapter_id) — sans ce trigger,
-- reclasser un chapitre (updateChapter, ou merge_academic_class_nodes) laisserait ses exercices
-- pointer vers l'ancienne classe.
CREATE OR REPLACE FUNCTION cascade_chapter_class_scope_to_exercises() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.class_node_id IS DISTINCT FROM OLD.class_node_id
       OR NEW.term_id IS DISTINCT FROM OLD.term_id THEN
        UPDATE exercises SET class_node_id = NEW.class_node_id, term_id = NEW.term_id
        WHERE chapter_id = NEW.id
           OR lesson_id IN (SELECT id FROM lessons WHERE chapter_id = NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cascade_chapter_class_scope ON chapters;
CREATE TRIGGER trg_cascade_chapter_class_scope
AFTER UPDATE OF class_node_id, term_id ON chapters
FOR EACH ROW EXECUTE FUNCTION cascade_chapter_class_scope_to_exercises();

-- ── Complète merge_academic_class_nodes : elle ne touchait ni chapters.class_node_id ni
-- exercises.class_node_id, laissant le contenu pédagogique orphelin après une fusion de classes.
CREATE OR REPLACE FUNCTION merge_academic_class_nodes(
    p_source_id UUID,
    p_target_id UUID,
    p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_source_type TEXT;
    v_target_type TEXT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    IF p_source_id = p_target_id THEN
        RAISE EXCEPTION 'Impossible de fusionner un nœud avec lui-même';
    END IF;

    SELECT node_type INTO v_source_type FROM academic_nodes WHERE id = p_source_id;
    SELECT node_type INTO v_target_type FROM academic_nodes WHERE id = p_target_id;

    IF v_source_type IS NULL OR v_target_type IS NULL THEN
        RAISE EXCEPTION 'Nœud source ou cible introuvable';
    END IF;

    IF v_source_type != v_target_type THEN
        RAISE EXCEPTION 'Les deux nœuds doivent être du même type (% != %)', v_source_type, v_target_type;
    END IF;

    IF v_source_type NOT IN ('class', 'series') THEN
        RAISE EXCEPTION 'Seules les Classes et Séries peuvent être fusionnées';
    END IF;

    UPDATE profiles SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    DELETE FROM subject_class_links scl
    WHERE scl.class_node_id = p_source_id
      AND EXISTS (
        SELECT 1 FROM subject_class_links t
        WHERE t.class_node_id = p_target_id AND t.subject_id = scl.subject_id
      );
    UPDATE subject_class_links SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE subscription_tiers SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE official_exams SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE establishment_papers SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE forum_threads SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE whatsapp_communities SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE events SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE announcements SET target_class_id = p_target_id WHERE target_class_id = p_source_id;

    UPDATE shop_documents SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    -- Contenu pédagogique : chapters.class_node_id déclenche trg_cascade_chapter_class_scope, qui
    -- répercute automatiquement sur les exercices Niveau 1/2. La ligne exercises directe reste
    -- nécessaire pour les exercices Niveau 3 (indépendants), que le trigger ne peut pas atteindre
    -- puisqu'ils n'ont ni chapter_id ni lesson_id.
    UPDATE chapters SET class_node_id = p_target_id WHERE class_node_id = p_source_id;
    UPDATE exercises SET class_node_id = p_target_id WHERE class_node_id = p_source_id;

    UPDATE academic_nodes SET parent_id = p_target_id WHERE parent_id = p_source_id;

    UPDATE academic_nodes SET is_active = FALSE, updated_at = NOW() WHERE id = p_source_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        p_admin_id, 'merge', 'academic_node', p_target_id,
        jsonb_build_object('source_id', p_source_id, 'node_type', v_source_type),
        jsonb_build_object('target_id', p_target_id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION merge_academic_class_nodes(UUID, UUID, UUID) TO authenticated;

-- ── Réécrit duplicate_chapter_to_class : l'ancienne version ne capturait aucune correspondance
-- ancien id de leçon -> nouvel id (impossible de re-parenter les exercices Niveau 1), et ne
-- dupliquait aucun exercice du tout.
CREATE OR REPLACE FUNCTION duplicate_chapter_to_class(
    p_chapter_id UUID,
    p_target_class_node_id UUID,
    p_admin_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_new_chapter_id UUID;
    v_term_id UUID;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    INSERT INTO chapters (subject_id, term_id, class_node_id, title, introduction, intro_media_json, display_order, is_active)
    SELECT subject_id, term_id, p_target_class_node_id, title, introduction, intro_media_json, display_order, is_active
    FROM chapters WHERE id = p_chapter_id
    RETURNING id, term_id INTO v_new_chapter_id, v_term_id;

    -- Duplique les leçons avec un id généré à l'avance, pour connaître le mapping ancien->nouveau
    -- dans la même requête (un simple INSERT...SELECT ne permet pas de RETURNING l'id source).
    WITH old_lessons AS (
        SELECT id AS old_id, uuid_generate_v4() AS new_id, title, content_json, display_order, is_active, min_subscription_tier
        FROM lessons WHERE chapter_id = p_chapter_id
    ), inserted_lessons AS (
        INSERT INTO lessons (id, chapter_id, title, content_json, display_order, is_published, is_active, min_subscription_tier)
        SELECT new_id, v_new_chapter_id, title, content_json, display_order, FALSE, is_active, min_subscription_tier
        FROM old_lessons
        RETURNING id
    )
    -- Exercices Niveau 1 (rattachés à une leçon dupliquée) : re-parentés vers la nouvelle leçon.
    INSERT INTO exercises (lesson_id, chapter_id, type, difficulty, format, title, instructions_json,
                            solution_json, min_subscription_tier, is_published, is_active,
                            class_node_id, term_id)
    SELECT ol.new_id, NULL, e.type, e.difficulty, e.format, e.title, e.instructions_json,
           e.solution_json, e.min_subscription_tier, FALSE, e.is_active,
           p_target_class_node_id, v_term_id
    FROM exercises e
    JOIN old_lessons ol ON ol.old_id = e.lesson_id
    JOIN inserted_lessons il ON il.id = ol.new_id;

    -- Exercices Niveau 2 (rattachés directement au chapitre, pas à une leçon précise) : dupliqués
    -- directement contre le nouveau chapitre.
    INSERT INTO exercises (lesson_id, chapter_id, type, difficulty, format, title, instructions_json,
                            solution_json, min_subscription_tier, is_published, is_active,
                            class_node_id, term_id)
    SELECT NULL, v_new_chapter_id, type, difficulty, format, title, instructions_json,
           solution_json, min_subscription_tier, FALSE, is_active,
           p_target_class_node_id, v_term_id
    FROM exercises WHERE chapter_id = p_chapter_id AND lesson_id IS NULL;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        p_admin_id, 'duplicate_to_class', 'chapter', v_new_chapter_id,
        jsonb_build_object('source_chapter_id', p_chapter_id),
        jsonb_build_object('target_class_node_id', p_target_class_node_id)
    );

    RETURN v_new_chapter_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION duplicate_chapter_to_class(UUID, UUID, UUID) TO authenticated;

-- ============================================================================
-- Terminé côté SQL. Si tu vois encore "column ... does not exist" ou une erreur RPC "function
-- does not exist" après avoir exécuté ce fichier, préviens-moi avec le message exact.
--
-- ÉTAPE SUIVANTE (hors SQL Editor, dans un terminal avec la Supabase CLI installée) :
-- Déployer les fonctions IA pour que les boutons "Générer par IA" (Leçons et Exercices)
-- fonctionnent sans erreur CORS trompeuse :
--
--   supabase functions deploy ai-course-structuring
--   supabase functions deploy ai-exercise-generation
--
-- Puis définir les secrets nécessaires (Dashboard Supabase → Edge Functions → Secrets, ou CLI) :
--
--   supabase secrets set ANTHROPIC_API_KEY=xxxxx
--   supabase secrets set GEMINI_API_KEY=xxxxx
--   -- OU, en attendant d'avoir des clés API valides (mode démo sans appel réseau) :
--   supabase secrets set AI_MOCK_MODE=true
-- ============================================================================
