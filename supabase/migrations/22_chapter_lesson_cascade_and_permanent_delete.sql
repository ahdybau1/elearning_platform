-- ============================================================================
-- Archivage/réactivation en cascade + suppression définitive pour Chapitres et Leçons
-- ============================================================================
-- Audit de l'écran "Leçons & Cours" (page-by-page rigor pass, suite du travail sur l'Arbre
-- Académique) : archiver un chapitre ne touchait QUE `chapters.is_active`, laissant ses leçons
-- actives et incohérentes avec un chapitre marqué "ARCHIVÉ" — même bug de fond que la suppression
-- de nœuds avant migration 20. Et il n'existait aucune suppression définitive réelle pour les
-- chapitres/leçons (seulement l'archivage), contrairement à ce qui existe maintenant sur l'Arbre
-- Académique (migration 21).
--
-- Contrairement aux nœuds académiques, il n'existe ici aucune table de progression élève
-- référençant chapters/lessons par FK sans CASCADE (vérifié : `chapters`/`lessons`/`lesson_versions`/
-- `exercises` sont tous en ON DELETE CASCADE entre eux) — la suppression définitive n'a donc pas
-- besoin d'un garde-fou "élèves rattachés" comme pour permanently_delete_academic_node. Elle reste
-- réservée aux éléments déjà archivés (on force le passage par "Archiver" d'abord), et prévient
-- explicitement de ce qu'elle emporte avec elle (leçons, versions, exercices liés).

CREATE OR REPLACE FUNCTION deactivate_chapter_cascade(p_chapter_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    UPDATE chapters SET is_active = FALSE, updated_at = NOW() WHERE id = p_chapter_id;
    UPDATE lessons SET is_active = FALSE, updated_at = NOW() WHERE chapter_id = p_chapter_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'deactivate_cascade', 'chapter', p_chapter_id, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION deactivate_chapter_cascade(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION reactivate_chapter_cascade(p_chapter_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    UPDATE chapters SET is_active = TRUE, updated_at = NOW() WHERE id = p_chapter_id;
    UPDATE lessons SET is_active = TRUE, updated_at = NOW() WHERE chapter_id = p_chapter_id;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, after_json)
    VALUES (p_admin_id, 'reactivate_cascade', 'chapter', p_chapter_id, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION reactivate_chapter_cascade(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION permanently_delete_chapter(p_chapter_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_chapter RECORD;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_chapter FROM chapters WHERE id = p_chapter_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Chapitre introuvable';
    END IF;
    IF v_chapter.is_active THEN
        RAISE EXCEPTION 'Archivez ce chapitre avant de le supprimer définitivement';
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'chapter', p_chapter_id,
            jsonb_build_object(
                'chapter_title', v_chapter.title,
                'lesson_count', (SELECT COUNT(*) FROM lessons WHERE chapter_id = p_chapter_id),
                'exercise_count', (SELECT COUNT(*) FROM exercises WHERE chapter_id = p_chapter_id
                                   OR lesson_id IN (SELECT id FROM lessons WHERE chapter_id = p_chapter_id))
            ));

    DELETE FROM chapters WHERE id = p_chapter_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_chapter(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION permanently_delete_lesson(p_lesson_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_lesson RECORD;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_lesson FROM lessons WHERE id = p_lesson_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Leçon introuvable';
    END IF;
    IF v_lesson.is_active THEN
        RAISE EXCEPTION 'Archivez cette leçon avant de la supprimer définitivement';
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'lesson', p_lesson_id,
            jsonb_build_object(
                'lesson_title', v_lesson.title,
                'exercise_count', (SELECT COUNT(*) FROM exercises WHERE lesson_id = p_lesson_id)
            ));

    DELETE FROM lessons WHERE id = p_lesson_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_lesson(UUID, UUID) TO authenticated;
