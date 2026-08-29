-- IA-010 "Learning intelligence" — MisconceptionAgent (AIA-AGT-009). Règle explicite du cahier :
-- « Une hypothèse n'est jamais stockée comme vérité définitive ; version/confidence obligatoires. »
-- -> status démarre TOUJOURS à 'candidate' côté agent (jamais 'confirmed' écrit par l'IA elle-même,
-- même règle de séparation que CorrectionAgent/official_correct, migration 68).

CREATE TABLE IF NOT EXISTS student_misconceptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    skill_id UUID REFERENCES skills(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    confidence NUMERIC(4,3) NOT NULL DEFAULT 0,
    evidence_attempt_ids UUID[] NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'candidate' CHECK (status IN ('candidate', 'confirmed', 'dismissed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (profile_id, skill_id, description)
);

ALTER TABLE student_misconceptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_misconceptions_select ON student_misconceptions;
CREATE POLICY student_misconceptions_select ON student_misconceptions FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
-- Écriture (agent + confirmation admin) : service_role bypass RLS pour l'agent (Gateway) ; un admin
-- peut aussi changer 'status' vers confirmed/dismissed directement.
DROP POLICY IF EXISTS student_misconceptions_write ON student_misconceptions;
CREATE POLICY student_misconceptions_write ON student_misconceptions FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

NOTIFY pgrst, 'reload schema';
