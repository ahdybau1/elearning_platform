-- CF-004 (docs/CONTENT_FACTORY_IMPLEMENTATION_PLAN.md) : étend ai_agent_calls (créée en
-- 03_schema_community_admin_ai.sql) vers un minimum d'observabilité réel (§15 du cahier des charges
-- Agents IA) — request_id, modèle exact utilisé, durée, statut, message d'erreur. Ces valeurs étaient
-- déjà calculées dans les edge functions (durationMs, nom du modèle) mais seulement journalisées via
-- console.log, jamais persistées ; les appels IA échoués n'étaient même pas enregistrés du tout.
--
-- Purement additif : toutes les nouvelles colonnes sont nullable ou par défaut, aucune ligne
-- existante ni aucun lecteur actuel de ai_agent_calls n'est affecté.

ALTER TABLE ai_agent_calls ADD COLUMN IF NOT EXISTS request_id UUID DEFAULT uuid_generate_v4();
ALTER TABLE ai_agent_calls ADD COLUMN IF NOT EXISTS model TEXT;
ALTER TABLE ai_agent_calls ADD COLUMN IF NOT EXISTS duration_ms INT;
ALTER TABLE ai_agent_calls ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'success';
ALTER TABLE ai_agent_calls ADD COLUMN IF NOT EXISTS error_message TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ai_agent_calls_status_check'
    ) THEN
        ALTER TABLE ai_agent_calls
            ADD CONSTRAINT ai_agent_calls_status_check CHECK (status IN ('success', 'failed'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ai_agent_calls_created_at ON ai_agent_calls (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_agent_calls_failed ON ai_agent_calls (agent_type, created_at DESC)
    WHERE status = 'failed';
