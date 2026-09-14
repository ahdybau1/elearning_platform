-- WP4 — ADMINISTRATION DES INTÉGRATIONS (consigne #5). Additif pur.
--
-- `integrations` ne contient QUE de la configuration non secrète. Le champ `secret_ref` porte le
-- *nom* du function-secret Supabase requis (jamais sa valeur) — les secrets restent côté serveur,
-- lisibles uniquement par les Edge Functions. Aucune clé n'est stockée ici ni exposée au client.

CREATE TABLE IF NOT EXISTS integrations (
    key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('ai', 'storage', 'payment', 'messaging', 'other')),
    provider TEXT,
    description TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,       -- non secret : modèles, endpoints, options
    secret_ref TEXT,                                 -- NOM du function-secret requis (pas la valeur)
    docs_url TEXT,
    -- État de santé (rempli par integration-healthcheck) :
    connected BOOLEAN NOT NULL DEFAULT FALSE,
    last_check_at TIMESTAMPTZ,
    last_status TEXT NOT NULL DEFAULT 'never'
        CHECK (last_status IN ('never', 'ok', 'error', 'not_configured')),
    last_error TEXT,
    last_latency_ms INT,
    known_limits JSONB NOT NULL DEFAULT '{}'::jsonb, -- quotas connus (free tier, etc.)
    license_note TEXT,
    cost_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS integrations_select ON integrations;
CREATE POLICY integrations_select ON integrations FOR SELECT USING (is_admin_user());
DROP POLICY IF EXISTS integrations_write ON integrations;
CREATE POLICY integrations_write ON integrations FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

CREATE OR REPLACE FUNCTION touch_integrations_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_integrations_touch ON integrations;
CREATE TRIGGER trg_integrations_touch BEFORE UPDATE ON integrations
    FOR EACH ROW EXECUTE FUNCTION touch_integrations_updated_at();

-- Seed : les intégrations RÉELLEMENT présentes dans le projet (function-secrets vérifiés).
INSERT INTO integrations (key, name, category, provider, description, enabled, config, secret_ref, docs_url, known_limits, license_note, cost_note) VALUES
(
    'gemini_generative', 'Gemini — génération de texte', 'ai', 'google',
    'Modèle génératif utilisé par le tuteur, la structuration de cours, la génération d''exercices et l''assistant admin.',
    TRUE,
    '{"model": "gemini-3.6-flash", "endpoint": "https://generativelanguage.googleapis.com/v1beta"}'::jsonb,
    'GEMINI_API_KEY',
    'https://ai.google.dev/gemini-api/docs',
    '{"free_tier": true, "note": "Quotas Free Tier Google — aucun plafond appliqué côté projet"}'::jsonb,
    'Google Gemini API — Free Tier (conditions Google AI Studio).',
    '0 $ (Free Tier). Aucune API IA payante obligatoire — contrainte projet respectée.'
),
(
    'gemini_embeddings', 'Gemini — embeddings (RAG)', 'ai', 'google',
    'Génération d''embeddings 768-dim pour l''indexation RAG (ai_rag_chunks).',
    TRUE,
    '{"model": "gemini-embedding-001", "dimensions": 768}'::jsonb,
    'GEMINI_API_KEY',
    'https://ai.google.dev/gemini-api/docs/embeddings',
    '{"free_tier": true, "max_texts_per_call": 100}'::jsonb,
    'Google Gemini API — Free Tier.',
    '0 $ (Free Tier).'
),
(
    'supabase_storage', 'Supabase Storage', 'storage', 'supabase',
    'Stockage des médias (illustrations, PDF, avatars). Références en base, droits via RLS/policies de bucket.',
    TRUE,
    '{"buckets": ["avatars", "media"]}'::jsonb,
    NULL,
    'https://supabase.com/docs/guides/storage',
    '{"note": "Inclus dans le plan Supabase du projet"}'::jsonb,
    'Supabase (plan du projet).',
    'Inclus dans l''abonnement Supabase existant.'
),
(
    'payment_mobile_money', 'Paiement Mobile Money', 'payment', NULL,
    'Encaissement des abonnements via agrégateur Mobile Money (MTN MoMo / Orange Money). Webhook payment-webhook déployé, en attente du contrat marchand.',
    FALSE,
    '{"webhook_function": "payment-webhook", "providers_cibles": ["MTN MoMo", "Orange Money"]}'::jsonb,
    'PAYMENT_WEBHOOK_SECRET',
    NULL,
    '{}'::jsonb,
    'À définir avec l''agrégateur.',
    'Non connecté : aucun débit réel ni simulé. En attente du contrat agrégateur.'
)
ON CONFLICT (key) DO NOTHING;

-- payment_mobile_money : statut initial honnête (non configuré, pas « jamais testé »).
UPDATE integrations SET last_status = 'not_configured'
WHERE key = 'payment_mobile_money' AND last_status = 'never';
