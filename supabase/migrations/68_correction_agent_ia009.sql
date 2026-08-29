-- IA-009 "Exercise vertical slice" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22) : ExerciseAgent (déjà
-- réel, AIA-AGT-004) + CorrectionAgent (AIA-AGT-005, nouveau) + validation humaine.
--
-- Règle explicite du cahier pour CorrectionAgent : « Séparer machine_score, confidence, feedback et
-- official_grade. Une note officielle nécessitant validation humaine ne peut être écrite directement. »
-- -> les colonnes ai_* sont écrites par l'agent (service_role, Gateway) ; official_correct ne peut
-- être écrite QUE par un admin (RLS ci-dessous), jamais directement par l'IA.
--
-- Ne concerne que reponse_courte/redaction : le QCM a déjà une correction déterministe exacte
-- (comparaison d'index côté client, is_correct déjà fiable) — CorrectionAgent n'y ajouterait rien.

ALTER TABLE exercise_attempts
    ADD COLUMN IF NOT EXISTS ai_score NUMERIC(4,3),
    ADD COLUMN IF NOT EXISTS ai_confidence NUMERIC(4,3),
    ADD COLUMN IF NOT EXISTS ai_feedback TEXT,
    ADD COLUMN IF NOT EXISTS ai_misconceptions TEXT[],
    ADD COLUMN IF NOT EXISTS needs_human_review BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS official_correct BOOLEAN,
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES admin_users(id),
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- Un admin peut relire/valider une tentative (poser official_correct/reviewed_by/reviewed_at) — c'est
-- la "validation humaine" exigée par IA-009. L'élève garde uniquement SELECT/INSERT (policies
-- existantes, migration 64) : jamais d'UPDATE côté élève, une tentative ne se corrige pas
-- rétroactivement par l'élève lui-même.
DROP POLICY IF EXISTS exercise_attempts_review ON exercise_attempts;
CREATE POLICY exercise_attempts_review ON exercise_attempts FOR UPDATE USING (is_admin_user()) WITH CHECK (is_admin_user());

NOTIFY pgrst, 'reload schema';
