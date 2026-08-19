-- Fonction de fusion de deux Classes ou deux Séries de l'arbre académique (Section 3.2 du CDC,
-- écran Arbre Académique). Voir reset_project_schema.sql pour le commentaire détaillé — gardé
-- identique ici pour que les deux fichiers restent en phase.
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
