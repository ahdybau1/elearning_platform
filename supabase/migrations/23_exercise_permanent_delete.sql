-- ============================================================================
-- Suppression définitive pour les Exercices
-- ============================================================================
-- Audit de l'écran "Banque d'Exercices" (page-by-page rigor pass, suite du travail sur l'Arbre
-- Académique et Leçons & Cours) : comme les Chapitres/Leçons avant leur correction, il n'existait
-- aucune suppression définitive réelle pour les exercices (seulement l'archivage via
-- `updateExercise(isActive: ...)`, sans même de confirmation côté UI). Un exercice est une feuille
-- (aucun enfant), donc contrairement aux Chapitres, une seule fonction suffit — pas besoin de
-- variante "cascade" pour l'archivage/réactivation. `exercise_versions` est en ON DELETE CASCADE
-- sur exercises(id), donc la suppression définitive n'a besoin d'aucun garde-fou de dépendance
-- externe au-delà d'exiger l'archivage préalable (même principe que academic_nodes/chapters).

CREATE OR REPLACE FUNCTION permanently_delete_exercise(p_exercise_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_exercise RECORD;
BEGIN
    IF NOT is_admin_user() THEN
        RAISE EXCEPTION 'Action réservée aux administrateurs';
    END IF;

    SELECT * INTO v_exercise FROM exercises WHERE id = p_exercise_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Exercice introuvable';
    END IF;
    IF v_exercise.is_active THEN
        RAISE EXCEPTION 'Archivez cet exercice avant de le supprimer définitivement';
    END IF;

    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json)
    VALUES (p_admin_id, 'permanent_delete', 'exercise', p_exercise_id,
            jsonb_build_object('exercise_title', v_exercise.title));

    DELETE FROM exercises WHERE id = p_exercise_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION permanently_delete_exercise(UUID, UUID) TO authenticated;
