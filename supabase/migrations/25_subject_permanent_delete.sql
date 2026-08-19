-- ============================================================================
-- Suppression définitive pour les Matières
-- ============================================================================
-- Audit de l'écran "Catalogue Pédagogique" (page-by-page rigor pass) : comme les
-- Chapitres/Leçons/Exercices avant leur correction, il n'existait aucune suppression définitive
-- réelle pour les matières (seulement l'archivage, sans confirmation ni retour côté UI).
--
-- Contrairement aux entités précédentes, `chapters.subject_id` est en ON DELETE CASCADE : supprimer
-- une matière supprimerait donc physiquement TOUS ses chapitres (et leurs leçons/exercices) dans
-- TOUTES les classes qui l'utilisent — un rayon d'action bien plus large qu'un chapitre ou un
-- exercice isolé. On bloque donc explicitement tant qu'il reste des chapitres rattachés, en plus
-- d'exiger l'archivage préalable (même principe que les autres suppressions définitives).
-- subject_class_links et content_catalog, eux, sont de la pure métadonnée relationnelle : leur
-- suppression en cascade ne perd aucun contenu pédagogique réel.
CREATE OR REPLACE FUNCTION permanently_delete_subject(p_subject_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_subject RECORD;
    v_chapter_count INT;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_subject FROM subjects WHERE id = p_subject_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Matière introuvable';
    END IF;
    IF v_subject.is_active THEN
        RAISE EXCEPTION 'Archivez cette matière avant de la supprimer définitivement';
    END IF;

    SELECT COUNT(*) INTO v_chapter_count FROM chapters WHERE subject_id = p_subject_id;
    IF v_chapter_count > 0 THEN
        RAISE EXCEPTION 'Suppression impossible : % chapitre(s) (et leurs leçons/exercices) sont encore rattachés à cette matière. Supprimez-les d''abord.', v_chapter_count;
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'subject', p_subject_id,
            jsonb_build_object('subject_name', v_subject.name));

    DELETE FROM subjects WHERE id = p_subject_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_subject(UUID, UUID) TO authenticated;
