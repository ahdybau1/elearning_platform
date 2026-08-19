-- ============================================================================
-- Réactivation en cascade + suppression définitive (réelle) de nœuds de l'Arbre Académique
-- ============================================================================
-- Jusqu'ici, un nœud "supprimé" (désactivé en cascade par deactivate_academic_node_cascade,
-- migration 20) ne pouvait être réactivé qu'un par un via le formulaire "Modifier" (isActive),
-- ce qui laissait ses descendants inactifs — donnant l'impression que la réactivation ne
-- fonctionnait pas. Et "Supprimer Définitivement" ne supprimait en réalité jamais rien (juste un
-- alias de la désactivation), sans jamais offrir de vraie suppression physique.
--
-- Ces deux fonctions comblent ces manques :
--   - reactivate_academic_node_cascade : symétrique de deactivate_academic_node_cascade.
--   - permanently_delete_academic_node : suppression physique réelle (DELETE), réservée aux nœuds
--     déjà désactivés (on force le passage par "Désactiver" d'abord) et qui vérifie explicitement
--     qu'aucun élève (profiles) n'est rattaché au sous-arbre avant de tenter la suppression — le
--     reste des références sans CASCADE (subscription_tiers, promotion_records, announcements...)
--     est laissé à la contrainte FK elle-même, dont la violation est interceptée pour renvoyer un
--     message clair plutôt qu'une erreur Postgres brute.

CREATE OR REPLACE FUNCTION reactivate_academic_node_cascade(p_node_id UUID, p_admin_id UUID)
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

    UPDATE academic_nodes SET is_active = TRUE, updated_at = NOW() WHERE id = ANY(v_affected_ids);

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'reactivate_cascade', 'academic_node', p_node_id,
            jsonb_build_object('affected_ids', v_affected_ids));

    RETURN v_affected_ids;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION reactivate_academic_node_cascade(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION permanently_delete_academic_node(p_node_id UUID, p_admin_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_node RECORD;
    v_affected_ids UUID[];
    v_student_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_node FROM academic_nodes WHERE id = p_node_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Nœud introuvable';
    END IF;
    IF v_node.is_active THEN
        RAISE EXCEPTION 'Désactivez ce nœud avant de le supprimer définitivement';
    END IF;

    WITH RECURSIVE descendants AS (
        SELECT id FROM academic_nodes WHERE id = p_node_id
        UNION ALL
        SELECT n.id FROM academic_nodes n
        JOIN descendants d ON n.parent_id = d.id
    )
    SELECT array_agg(id) INTO v_affected_ids FROM descendants;

    SELECT COUNT(*) INTO v_student_count
    FROM profiles WHERE class_node_id = ANY(v_affected_ids);
    IF v_student_count > 0 THEN
        RAISE EXCEPTION 'Suppression impossible : % élève(s) encore rattaché(s) à ce nœud ou à ses descendants', v_student_count;
    END IF;

    -- L'entrée d'audit est écrite AVANT la suppression physique : entity_id n'a pas de contrainte
    -- de clé étrangère vers academic_nodes (table polymorphe), la trace survit donc au DELETE.
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'academic_node', p_node_id,
            jsonb_build_object('node_name', v_node.name, 'node_type', v_node.node_type, 'affected_ids', v_affected_ids));

    BEGIN
        DELETE FROM academic_nodes WHERE id = ANY(v_affected_ids);
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Suppression impossible : ce nœud ou l''un de ses descendants est encore référencé ailleurs dans le système (abonnements, annonces ciblées, historiques de promotion...). Retirez ces dépendances d''abord, ou laissez-le simplement désactivé.';
    END;

    RETURN v_affected_ids;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_academic_node(UUID, UUID) TO authenticated;
