-- ============================================================================
-- Approbation + publication atomique (File de Validation)
-- ============================================================================
-- Audit de l'écran "File de Validation" (page-by-page rigor pass) : `approveContent` faisait deux
-- appels Supabase séparés (marquer `validation_queue.status = 'approuve'`, PUIS publier
-- `lessons`/`exercises.is_published = true`). Si le second échouait (coupure réseau, RLS...), la
-- ligne de queue restait "approuvée" alors que le contenu n'était jamais publié — l'élément
-- disparaissait de l'onglet "En attente" sans qu'aucune trace ne permette de détecter l'incohérence
-- ni de la corriger. Cette fonction regroupe les deux écritures dans une seule transaction
-- SECURITY DEFINER : soit les deux réussissent, soit aucune n'est appliquée.
CREATE OR REPLACE FUNCTION approve_and_publish_content(p_validation_id UUID, p_reviewer_id UUID)
RETURNS VOID AS $$
DECLARE
    v_content_type TEXT;
    v_content_id UUID;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT content_type, content_id INTO v_content_type, v_content_id
    FROM validation_queue WHERE id = p_validation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Entrée de validation introuvable';
    END IF;

    UPDATE validation_queue
    SET status = 'approuve', reviewer_id = p_reviewer_id, reviewed_at = NOW()
    WHERE id = p_validation_id;

    IF v_content_type = 'lesson' THEN
        UPDATE lessons SET is_published = TRUE WHERE id = v_content_id;
    ELSIF v_content_type = 'exercise' THEN
        UPDATE exercises SET is_published = TRUE WHERE id = v_content_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION approve_and_publish_content(UUID, UUID) TO authenticated;
