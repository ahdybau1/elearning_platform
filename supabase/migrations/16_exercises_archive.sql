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
