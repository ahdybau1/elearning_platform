-- WP2 — ADMIN AI CONTROL PLANE (docs/CAHIER_TECHNIQUE_ADMIN_AI_CONTROL_PLANE.md ADM-077..093 ;
-- docs/CAHIER_DES_CHARGES_AGENTS_IA.md §9 ; consigne #4 « centraliser la gestion de tous les
-- agents IA prévus »).
--
-- Additif pur. Étend le registre IA-001 (migration 55) avec les paramètres réellement
-- administrables depuis l'admin, ajoute l'historique d'exécutions unitaires (ai_agent_runs) et le
-- suivi de workflows multi-agents (ai_workflows / ai_workflow_steps). Runtime = Edge Functions
-- Supabase uniquement (contrainte coût zéro ; le Gateway FastAPI n'est pas déployé — les agents
-- marqués runtime='gateway_native' sont catalogués mais signalés « hors ligne » dans l'UI).

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ai_agents : colonnes de pilotage (niveau agent)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE ai_agents ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE ai_agents ADD COLUMN IF NOT EXISTS requires_human_review BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE ai_agents ADD COLUMN IF NOT EXISTS depends_on TEXT[] NOT NULL DEFAULT '{}';
-- 'edge_function' = exécuté par une Edge Function Deno déployée ; 'gateway_native' = défini dans
-- gateway/app/ mais Gateway non déployé → injoignable ; 'none' = pas encore d'implémentation.
ALTER TABLE ai_agents ADD COLUMN IF NOT EXISTS runtime TEXT NOT NULL DEFAULT 'edge_function'
    CHECK (runtime IN ('edge_function', 'gateway_native', 'none'));
ALTER TABLE ai_agents ADD COLUMN IF NOT EXISTS description TEXT;

-- Backfill runtime depuis la dernière version enregistrée (edge_function_name).
UPDATE ai_agents a SET runtime = sub.rt
FROM (
    SELECT DISTINCT ON (v.agent_id) v.agent_id,
        CASE
            WHEN v.edge_function_name IS NULL THEN 'none'
            WHEN v.edge_function_name = 'gateway_native' THEN 'gateway_native'
            ELSE 'edge_function'
        END AS rt
    FROM ai_agent_versions v
    ORDER BY v.agent_id, v.created_at DESC
) sub
WHERE sub.agent_id = a.id AND a.runtime = 'edge_function';

-- Agents sans aucune version → 'none'.
UPDATE ai_agents a SET runtime = 'none'
WHERE NOT EXISTS (SELECT 1 FROM ai_agent_versions v WHERE v.agent_id = a.id)
  AND a.runtime <> 'none';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. ai_agent_versions : prompt éditable, outils/sources autorisés, limites, repli
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE ai_agent_versions ADD COLUMN IF NOT EXISTS prompt_template TEXT;
ALTER TABLE ai_agent_versions ADD COLUMN IF NOT EXISTS prompt_notes TEXT;
ALTER TABLE ai_agent_versions ADD COLUMN IF NOT EXISTS allowed_tools TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE ai_agent_versions ADD COLUMN IF NOT EXISTS allowed_sources TEXT[] NOT NULL DEFAULT '{}';
-- limits : { "max_tokens": int, "timeout_ms": int, "max_concurrency": int }
ALTER TABLE ai_agent_versions ADD COLUMN IF NOT EXISTS limits JSONB NOT NULL DEFAULT '{}'::jsonb;
-- fallback_strategy : { "retry": int, "backoff_ms": int, "fallback_agent": "agent_key" | null }
ALTER TABLE ai_agent_versions ADD COLUMN IF NOT EXISTS fallback_strategy JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Rattachement des 2 agents portés en Edge Function pendant le WP1
--    (ai-curriculum-mapping, ai-pedagogical-validation) — remplacent 'gateway_native'.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE ai_agent_versions v SET edge_function_name = 'ai-curriculum-mapping'
FROM ai_agents a
WHERE v.agent_id = a.id AND a.agent_id = 'AIA-AGT-017' AND v.edge_function_name = 'gateway_native';

UPDATE ai_agent_versions v SET edge_function_name = 'ai-pedagogical-validation'
FROM ai_agents a
WHERE v.agent_id = a.id AND a.agent_id = 'AIA-AGT-024' AND v.edge_function_name = 'gateway_native';

UPDATE ai_agents SET runtime = 'edge_function'
WHERE agent_id IN ('AIA-AGT-017', 'AIA-AGT-024');

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ai_agent_runs : historique d'exécutions unitaires (avec I/O), consigne #4
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_workflows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_key TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'paused', 'completed', 'failed', 'cancelled')),
    progress_pct INT NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
    context JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_message TEXT,
    started_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_agent_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id UUID REFERENCES ai_agents(id) ON DELETE CASCADE,
    agent_version_id UUID REFERENCES ai_agent_versions(id) ON DELETE SET NULL,
    -- Dénormalisé pour un filtre direct (ai_agents.agent_id, ex: 'AIA-AGT-024').
    agent_key TEXT NOT NULL,
    workflow_id UUID REFERENCES ai_workflows(id) ON DELETE SET NULL,
    trigger TEXT NOT NULL DEFAULT 'manual_test'
        CHECK (trigger IN ('manual_test', 'workflow', 'production')),
    triggered_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    input_preview JSONB,            -- entrée (éventuellement tronquée) — jamais de secret
    output JSONB,                   -- sortie structurée
    output_valid BOOLEAN,           -- résultat de la validation de schéma de sortie
    status TEXT NOT NULL DEFAULT 'running'
        CHECK (status IN ('running', 'success', 'failed', 'cancelled')),
    error_message TEXT,
    tokens_used INT NOT NULL DEFAULT 0,
    duration_ms INT,
    cost_estimate NUMERIC(12, 6) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ai_agent_runs_agent_key ON ai_agent_runs (agent_key, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_agent_runs_workflow ON ai_agent_runs (workflow_id);

CREATE TABLE IF NOT EXISTS ai_workflow_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_id UUID NOT NULL REFERENCES ai_workflows(id) ON DELETE CASCADE,
    step_index INT NOT NULL,
    agent_key TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'success', 'failed', 'skipped')),
    run_id UUID REFERENCES ai_agent_runs(id) ON DELETE SET NULL,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    UNIQUE (workflow_id, step_index)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RLS — lecture tout admin actif, écriture super_admin (aligné migration 55).
--    Les Edge Functions écrivent via service_role (contourne RLS).
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE ai_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_agent_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_workflow_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_workflows_select ON ai_workflows;
CREATE POLICY ai_workflows_select ON ai_workflows FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_workflows_write ON ai_workflows;
CREATE POLICY ai_workflows_write ON ai_workflows FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_agent_runs_select ON ai_agent_runs;
CREATE POLICY ai_agent_runs_select ON ai_agent_runs FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_agent_runs_write ON ai_agent_runs;
CREATE POLICY ai_agent_runs_write ON ai_agent_runs FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_workflow_steps_select ON ai_workflow_steps;
CREATE POLICY ai_workflow_steps_select ON ai_workflow_steps FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS ai_workflow_steps_write ON ai_workflow_steps;
CREATE POLICY ai_workflow_steps_write ON ai_workflow_steps FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Journal append-only des changements de config d'agent (réutilise audit_log).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION log_ai_config_change() RETURNS TRIGGER AS $$
DECLARE
    v_admin UUID;
BEGIN
    SELECT id INTO v_admin FROM admin_users WHERE auth_user_id = auth.uid() LIMIT 1;
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        v_admin,
        'ai_config_update',
        TG_TABLE_NAME,
        NEW.id,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ai_agents_config_audit ON ai_agents;
CREATE TRIGGER trg_ai_agents_config_audit
    AFTER UPDATE ON ai_agents
    FOR EACH ROW EXECUTE FUNCTION log_ai_config_change();

DROP TRIGGER IF EXISTS trg_ai_agent_versions_config_audit ON ai_agent_versions;
CREATE TRIGGER trg_ai_agent_versions_config_audit
    AFTER UPDATE ON ai_agent_versions
    FOR EACH ROW EXECUTE FUNCTION log_ai_config_change();

-- updated_at auto sur ai_workflows
CREATE OR REPLACE FUNCTION touch_ai_workflow_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ai_workflows_touch ON ai_workflows;
CREATE TRIGGER trg_ai_workflows_touch
    BEFORE UPDATE ON ai_workflows
    FOR EACH ROW EXECUTE FUNCTION touch_ai_workflow_updated_at();
