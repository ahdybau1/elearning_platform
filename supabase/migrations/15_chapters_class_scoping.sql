-- Corrige un vrai défaut de conception détecté en test : les chapitres n'étaient rattachés qu'à
-- une matière (subject_id), jamais à une classe précise. Comme le seed lie "Mathématiques" à la
-- fois à "3e" ET "Tle C" (subject_class_links sert seulement à dire "cette matière est enseignée
-- dans cette classe", pas "ces classes partagent le même contenu"), tout chapitre créé sous
-- "Mathématiques" apparaissait dans les DEUX classes — un chapitre de 3e sur Pythagore se
-- serait retrouvé visible en Terminale C. Ce n'était pas des "classes jumelées", c'était une
-- fuite de contenu entre niveaux totalement différents.
--
-- Un chapitre appartient maintenant à UNE classe/série précise. Le vrai jumelage de classes (ex:
-- Tle C et Tle D qui étudient parfois le même programme de maths) se fait désormais explicitement
-- via duplication (voir duplicate_chapter_to_class ci-dessous), jamais par partage implicite.
ALTER TABLE chapters ADD COLUMN IF NOT EXISTS class_node_id UUID REFERENCES academic_nodes(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_chapters_class_node_id ON chapters(class_node_id);

-- Duplique un chapitre (et ses leçons) vers une autre classe/série, pour le cas légitime de
-- classes dont le programme est identique (ex: séries jumelées). Duplication réelle et
-- indépendante — pas de référence partagée — pour qu'une modification ultérieure sur l'une
-- n'affecte jamais l'autre.
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
