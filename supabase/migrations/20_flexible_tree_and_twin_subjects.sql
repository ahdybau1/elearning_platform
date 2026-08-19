-- ============================================================================
-- Suppression en cascade dans l'Arbre Académique
-- ============================================================================
-- `deleteNode` ne désactivait jusqu'ici QUE la ligne ciblée, alors que la boîte de confirmation
-- de l'admin affirme (à tort) que les enfants sont eux aussi désactivés — un pays "supprimé"
-- laissait ses sections/classes actives et visibles dès que "Afficher les nœuds inactifs" était
-- coché, un état incohérent. Cette fonction désactive le nœud ET tous ses descendants (CTE
-- récursive sur parent_id) en une seule transaction, avec une entrée audit_log listant les ids
-- affectés.
CREATE OR REPLACE FUNCTION deactivate_academic_node_cascade(p_node_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_affected_ids UUID[];
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    WITH RECURSIVE descendants AS (
        SELECT id FROM academic_nodes WHERE id = p_node_id
        UNION ALL
        SELECT n.id FROM academic_nodes n
        JOIN descendants d ON n.parent_id = d.id
    )
    SELECT array_agg(id) INTO v_affected_ids FROM descendants;

    UPDATE academic_nodes SET is_active = FALSE, updated_at = NOW() WHERE id = ANY(v_affected_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'deactivate_cascade', 'academic_node', p_node_id,
            jsonb_build_object('affected_ids', v_affected_ids));

    RETURN v_affected_ids;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION deactivate_academic_node_cascade(UUID, UUID) TO authenticated;

-- ============================================================================
-- Jumelage précis par matière (au lieu d'un jumelage générique par classe)
-- ============================================================================
-- "Ces classes sont jumelées" ne veut souvent dire vrai que POUR UNE MATIÈRE précise (ex: mêmes
-- classes, programmes différents en Français). class_twin_groups gagne donc un subject_id, et une
-- classe peut désormais appartenir à plusieurs groupes (un par matière) — la contrainte UNIQUE qui
-- limitait une classe à un seul groupe au total n'a plus lieu d'être.
ALTER TABLE class_twin_groups ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE;

ALTER TABLE class_twin_group_members DROP CONSTRAINT IF EXISTS class_twin_group_members_class_node_id_key;

-- CREATE OR REPLACE ne suffit pas ici : la liste de paramètres change (ajout de p_subject_id),
-- donc Postgres créerait une surcharge supplémentaire au lieu de remplacer l'ancienne signature —
-- on la supprime explicitement d'abord pour ne pas laisser deux versions de la fonction.
DROP FUNCTION IF EXISTS declare_class_twin_group(UUID[], TEXT, UUID);

-- Redéclare avec la validation de matière : chaque classe du groupe doit réellement enseigner
-- cette matière (subject_class_links), sinon le jumelage n'a pas de sens.
CREATE OR REPLACE FUNCTION declare_class_twin_group(
    p_class_node_ids UUID[],
    p_subject_id UUID,
    p_label TEXT,
    p_admin_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_group_id UUID;
    v_type_count INT;
    v_missing_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;
    IF array_length(p_class_node_ids, 1) IS NULL OR array_length(p_class_node_ids, 1) < 2 THEN
        RAISE EXCEPTION 'Un groupe jumelé nécessite au moins 2 classes/séries';
    END IF;
    IF p_subject_id IS NULL THEN
        RAISE EXCEPTION 'Un jumelage doit préciser la matière concernée';
    END IF;

    SELECT COUNT(DISTINCT node_type) INTO v_type_count
    FROM academic_nodes WHERE id = ANY(p_class_node_ids) AND node_type IN ('class', 'series');
    IF v_type_count != 1 THEN
        RAISE EXCEPTION 'Toutes les classes du groupe doivent être du même type (Classe ou Série)';
    END IF;

    SELECT COUNT(*) INTO v_missing_count
    FROM unnest(p_class_node_ids) cid
    WHERE NOT EXISTS (
        SELECT 1 FROM subject_class_links WHERE class_node_id = cid AND subject_id = p_subject_id
    );
    IF v_missing_count > 0 THEN
        RAISE EXCEPTION 'Cette matière n''est pas enseignée dans toutes les classes sélectionnées';
    END IF;

    INSERT INTO class_twin_groups (label, subject_id, created_by) VALUES (p_label, p_subject_id, p_admin_id)
    RETURNING id INTO v_group_id;
    INSERT INTO class_twin_group_members (group_id, class_node_id)
    SELECT v_group_id, unnest(p_class_node_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'twin_declare', 'class_twin_group', v_group_id,
            jsonb_build_object('class_node_ids', p_class_node_ids, 'subject_id', p_subject_id));

    RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION declare_class_twin_group(UUID[], UUID, TEXT, UUID) TO authenticated;

-- Une classe pouvant désormais être dans plusieurs groupes (un par matière), on résout le groupe
-- dont la matière correspond à celle du chapitre dupliqué, pas "le" groupe de la classe.
CREATE OR REPLACE FUNCTION duplicate_chapter_to_twin_group(p_chapter_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_group_id UUID;
    v_source_class_id UUID;
    v_chapter_subject_id UUID;
    v_target_id UUID;
    v_results UUID[] := ARRAY[]::UUID[];
BEGIN
    IF NOT is_admin_user() THEN RAISE EXCEPTION 'Action réservée aux administrateurs'; END IF;

    SELECT class_node_id, subject_id INTO v_source_class_id, v_chapter_subject_id
    FROM chapters WHERE id = p_chapter_id;
    IF v_source_class_id IS NULL THEN RAISE EXCEPTION 'Chapitre introuvable ou sans classe associée'; END IF;

    SELECT m.group_id INTO v_group_id
    FROM class_twin_group_members m
    JOIN class_twin_groups g ON g.id = m.group_id
    WHERE m.class_node_id = v_source_class_id AND g.subject_id = v_chapter_subject_id;
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Cette classe ne fait partie d''aucun groupe jumelé pour cette matière';
    END IF;

    FOR v_target_id IN
        SELECT class_node_id FROM class_twin_group_members WHERE group_id = v_group_id AND class_node_id != v_source_class_id
    LOOP
        v_results := array_append(v_results, duplicate_chapter_to_class(p_chapter_id, v_target_id, p_admin_id));
    END LOOP;

    RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION duplicate_chapter_to_twin_group(UUID, UUID) TO authenticated;
