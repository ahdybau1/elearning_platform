-- Migration 07: Publication des exercices
--
-- La table `exercises` n'a jamais eu de colonne de publication (contrairement à `lessons`), alors
-- que le CDC exige que TOUT contenu pédagogique passe par le workflow de validation avant d'être
-- visible (section 3.3). Sans cette colonne, un exercice inséré devenait immédiatement visible aux
-- élèves selon la policy RLS de lecture, sans jamais passer par `validation_queue`.
--
-- Rejouable sans erreur.

ALTER TABLE exercises ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT FALSE;

DROP POLICY IF EXISTS exercises_select ON exercises;
CREATE POLICY exercises_select ON exercises FOR SELECT USING (
    is_admin_user()
    OR (
        is_published = true
        AND (
            min_subscription_tier = 'gratuit'
            OR (type = 'entraînement' AND current_user_has_feature_access('exercises_training'))
            OR (type = 'évaluation' AND current_user_has_feature_access('exercises_evaluation'))
        )
    )
);
