-- "Jumelage" de classes/séries — jusqu'ici un concept purement informel (un commentaire de code
-- dans reset_project_schema.sql, jamais une donnée persistée). Ce fichier en fait une relation
-- N-aire réelle, interrogeable et réversible, distincte de merge_academic_class_nodes (qui reste
-- une consolidation destructive : la source est désactivée). Un jumelage n'implique AUCUNE fusion
-- — seulement "ces classes partagent le même programme et peuvent se propager du contenu entre
-- elles". N-aire (pas juste des paires) car les séries camerounaises sont souvent 3+ en parallèle.
CREATE TABLE IF NOT EXISTS class_twin_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label TEXT,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS class_twin_group_members (
    group_id UUID NOT NULL REFERENCES class_twin_groups(id) ON DELETE CASCADE,
    class_node_id UUID NOT NULL UNIQUE REFERENCES academic_nodes(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (group_id, class_node_id)
);
-- UNIQUE sur class_node_id (contrainte de colonne ci-dessus) : une classe n'appartient qu'à un
-- seul groupe jumelé à la fois — simplifie toute la résolution (jamais de multi-groupes).

ALTER TABLE class_twin_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_twin_group_members ENABLE ROW LEVEL SECURITY;

-- Purement un outil d'auteur admin, jamais consommé par l'app élève (contrairement à
-- subjects/chapters) : lecture ET écriture réservées aux admins.
DROP POLICY IF EXISTS class_twin_groups_admin_all ON class_twin_groups;
CREATE POLICY class_twin_groups_admin_all ON class_twin_groups FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());
DROP POLICY IF EXISTS class_twin_group_members_admin_all ON class_twin_group_members;
CREATE POLICY class_twin_group_members_admin_all ON class_twin_group_members FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

-- Déclare un nouveau groupe de classes jumelées (>= 2 membres, même node_type — même règle que
-- merge_academic_class_nodes). Une seule transaction : soit tout le groupe se crée, soit rien.
CREATE OR REPLACE FUNCTION declare_class_twin_group(
    p_class_node_ids UUID[],
    p_label TEXT,
    p_admin_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_group_id UUID;
    v_type_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;
    IF array_length(p_class_node_ids, 1) IS NULL OR array_length(p_class_node_ids, 1) < 2 THEN
        RAISE EXCEPTION 'Un groupe jumelé nécessite au moins 2 classes/séries';
    END IF;

    SELECT COUNT(DISTINCT node_type) INTO v_type_count
    FROM academic_nodes WHERE id = ANY(p_class_node_ids) AND node_type IN ('class', 'series');
    IF v_type_count != 1 THEN
        RAISE EXCEPTION 'Toutes les classes du groupe doivent être du même type (Classe ou Série)';
    END IF;

    INSERT INTO class_twin_groups (label, created_by) VALUES (p_label, p_admin_id) RETURNING id INTO v_group_id;
    INSERT INTO class_twin_group_members (group_id, class_node_id)
    SELECT v_group_id, unnest(p_class_node_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'twin_declare', 'class_twin_group', v_group_id, jsonb_build_object('class_node_ids', p_class_node_ids));

    RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION add_class_to_twin_group(p_group_id UUID, p_class_node_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;
    INSERT INTO class_twin_group_members (group_id, class_node_id) VALUES (p_group_id, p_class_node_id);
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'twin_add_member', 'class_twin_group', p_group_id, jsonb_build_object('class_node_id', p_class_node_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Dissout automatiquement le groupe s'il ne reste plus qu'un seul membre après retrait (un
-- jumelage à 1 classe n'a plus de sens).
CREATE OR REPLACE FUNCTION remove_class_from_twin_group(p_group_id UUID, p_class_node_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;
    DELETE FROM class_twin_group_members WHERE group_id = p_group_id AND class_node_id = p_class_node_id;
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'twin_remove_member', 'class_twin_group', p_group_id, jsonb_build_object('class_node_id', p_class_node_id));
    DELETE FROM class_twin_groups g
    WHERE g.id = p_group_id AND (SELECT COUNT(*) FROM class_twin_group_members WHERE group_id = p_group_id) < 2;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION dissolve_class_twin_group(p_group_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'twin_dissolve', 'class_twin_group', p_group_id,
        (SELECT jsonb_agg(class_node_id) FROM class_twin_group_members WHERE group_id = p_group_id));
    DELETE FROM class_twin_groups WHERE id = p_group_id; -- CASCADE supprime les membres
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION declare_class_twin_group(UUID[], TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_class_to_twin_group(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_class_from_twin_group(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION dissolve_class_twin_group(UUID, UUID) TO authenticated;

-- Aperçu d'impact avant une FUSION (pas un jumelage) — une seule fonction agrégée plutôt que 10
-- requêtes séparées côté client. Sert aussi à corriger le texte de confirmation périmé de
-- l'écran Arbre Académique, qui ne mentionnait pas chapitres/exercices (ajoutés par la migration 17).
CREATE OR REPLACE FUNCTION get_class_node_merge_impact(p_class_node_id UUID)
RETURNS TABLE(entity_key TEXT, entity_label TEXT, row_count BIGINT) AS $$
    SELECT 'profiles', 'Élèves rattachés', COUNT(*) FROM profiles WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'subject_class_links', 'Matières liées', COUNT(*) FROM subject_class_links WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'chapters', 'Chapitres', COUNT(*) FROM chapters WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'exercises', 'Exercices', COUNT(*) FROM exercises WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'subscription_tiers', 'Paliers tarifaires', COUNT(*) FROM subscription_tiers WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'official_exams', 'Examens officiels', COUNT(*) FROM official_exams WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'establishment_papers', 'Épreuves d''établissement', COUNT(*) FROM establishment_papers WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'forum_threads', 'Sujets du forum', COUNT(*) FROM forum_threads WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'whatsapp_communities', 'Communautés WhatsApp', COUNT(*) FROM whatsapp_communities WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'events', 'Événements', COUNT(*) FROM events WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'announcements', 'Annonces ciblées', COUNT(*) FROM announcements WHERE target_class_id = p_class_node_id
    UNION ALL SELECT 'shop_documents', 'Documents boutique', COUNT(*) FROM shop_documents WHERE class_node_id = p_class_node_id
    UNION ALL SELECT 'children_nodes', 'Nœuds enfants (ex: Séries)', COUNT(*) FROM academic_nodes WHERE parent_id = p_class_node_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_class_node_merge_impact(UUID) TO authenticated;

-- Duplique un chapitre vers TOUTES les classes de son groupe jumelé, en une seule transaction —
-- boucler duplicate_chapter_to_class depuis Dart laisserait un groupe à moitié synchronisé si un
-- appel intermédiaire échouait. Réutilise duplicate_chapter_to_class telle quelle (pas de logique
-- dupliquée).
CREATE OR REPLACE FUNCTION duplicate_chapter_to_twin_group(p_chapter_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_group_id UUID;
    v_source_class_id UUID;
    v_target_id UUID;
    v_results UUID[] := ARRAY[]::UUID[];
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;

    SELECT class_node_id INTO v_source_class_id FROM chapters WHERE id = p_chapter_id;
    IF v_source_class_id IS NULL THEN RAISE EXCEPTION 'Chapitre introuvable ou sans classe associée'; END IF;

    SELECT group_id INTO v_group_id FROM class_twin_group_members WHERE class_node_id = v_source_class_id;
    IF v_group_id IS NULL THEN RAISE EXCEPTION 'Cette classe ne fait partie d''aucun groupe de classes jumelées'; END IF;

    FOR v_target_id IN
        SELECT class_node_id FROM class_twin_group_members WHERE group_id = v_group_id AND class_node_id != v_source_class_id
    LOOP
        v_results := array_append(v_results, duplicate_chapter_to_class(p_chapter_id, v_target_id, p_admin_id));
    END LOOP;

    RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION duplicate_chapter_to_twin_group(UUID, UUID) TO authenticated;

-- Aperçu d'impact avant duplication (nb leçons/exercices concernés), pour un seul chapitre.
CREATE OR REPLACE FUNCTION get_chapter_duplication_impact(p_chapter_id UUID)
RETURNS TABLE(lesson_count BIGINT, exercise_count BIGINT) AS $$
    SELECT
      (SELECT COUNT(*) FROM lessons WHERE chapter_id = p_chapter_id),
      (SELECT COUNT(*) FROM exercises WHERE chapter_id = p_chapter_id
         OR lesson_id IN (SELECT id FROM lessons WHERE chapter_id = p_chapter_id));
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_chapter_duplication_impact(UUID) TO authenticated;
