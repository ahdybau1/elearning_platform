-- Migration 88 : Synchronisation multi-appareils des conversations de l'élève (limite 10)
-- Permet à l'élève de retrouver son historique de discussions avec le Tuteur pq learn quel que soit l'appareil.

CREATE TABLE IF NOT EXISTS student_chat_sessions (
    id TEXT PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Nouvelle discussion',
    messages JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_chat_sessions_profile_updated
    ON student_chat_sessions (profile_id, updated_at DESC);

-- Activation de la sécurité au niveau des lignes (RLS)
ALTER TABLE student_chat_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_chat_sessions_select ON student_chat_sessions;
CREATE POLICY student_chat_sessions_select ON student_chat_sessions
    FOR SELECT USING (owns_profile(profile_id));

DROP POLICY IF EXISTS student_chat_sessions_insert ON student_chat_sessions;
CREATE POLICY student_chat_sessions_insert ON student_chat_sessions
    FOR INSERT WITH CHECK (owns_profile(profile_id));

DROP POLICY IF EXISTS student_chat_sessions_update ON student_chat_sessions;
CREATE POLICY student_chat_sessions_update ON student_chat_sessions
    FOR UPDATE USING (owns_profile(profile_id)) WITH CHECK (owns_profile(profile_id));

DROP POLICY IF EXISTS student_chat_sessions_delete ON student_chat_sessions;
CREATE POLICY student_chat_sessions_delete ON student_chat_sessions
    FOR DELETE USING (owns_profile(profile_id));

-- Trigger automatique garantissant la limite stricte de 10 conversations par profil
CREATE OR REPLACE FUNCTION enforce_student_chat_sessions_limit() RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM student_chat_sessions
    WHERE profile_id = NEW.profile_id
      AND id NOT IN (
          SELECT id FROM student_chat_sessions
          WHERE profile_id = NEW.profile_id
          ORDER BY updated_at DESC
          LIMIT 10
      );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_enforce_student_chat_sessions_limit ON student_chat_sessions;
CREATE TRIGGER trg_enforce_student_chat_sessions_limit
    AFTER INSERT ON student_chat_sessions
    FOR EACH ROW EXECUTE FUNCTION enforce_student_chat_sessions_limit();

-- Nettoyage des caches statiques de salutations pollués par les suites arithmétiques
DELETE FROM ai_tutor_cache
WHERE reply ILIKE '%arithmétique%'
   OR reply ILIKE '%suite arithmétique%'
   OR reply ILIKE '%bonjour !%'
   OR reply ILIKE '%bonjour élève%';

NOTIFY pgrst, 'reload schema';
