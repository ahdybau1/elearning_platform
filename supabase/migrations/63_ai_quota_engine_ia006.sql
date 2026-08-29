-- IA-006 "Quota Engine" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §6) : "Policies, entitlements,
-- weighted compute units, ledger, fallback." Le cahier interdit explicitement de coder des valeurs
-- numériques de quotas en dur avant benchmark réel (§2 règle 10, §6 U7) — les policies sont donc
-- enregistrées avec allowance_units/concurrency_limit NULL ("pas encore déterminé"), pas des
-- chiffres inventés. Ce qui EST réel ici : la structure, la résolution d'entitlement à partir du
-- vrai subscription_tier d'un profil, et le ledger append-only qui commence à enregistrer l'usage
-- réel dès maintenant (pour avoir des données à benchmarker plus tard).

CREATE TABLE IF NOT EXISTS ai_policies (
    policy_key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    max_model_tier TEXT, -- NULL = pas de restriction décidée
    priority INT NOT NULL DEFAULT 0,
    concurrency_limit INT, -- NULL = illimité tant que non benchmarké
    allowance_units INT, -- NULL = pas encore déterminé par benchmark (§6/U7 du cahier)
    allowance_period TEXT CHECK (allowance_period IS NULL OR allowance_period IN ('day', 'week', 'month')),
    rollover BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Un profil = un entitlement actif (§6 : SUBSCRIPTION -> AI POLICY). Résolu depuis
-- profiles.subscription_tier (§37 du cahier maître : "point d'ancrage de toutes les règles
-- d'accès"), pas une nouvelle notion d'abonnement parallèle.
CREATE TABLE IF NOT EXISTS ai_entitlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    policy_key TEXT NOT NULL REFERENCES ai_policies(policy_key),
    source TEXT NOT NULL DEFAULT 'subscription_tier',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Append-only (§6 : "Les corrections se font par écritures compensatoires, pas par réécriture
-- silencieuse") — aucun UPDATE/DELETE prévu sur cette table par l'application.
CREATE TABLE IF NOT EXISTS ai_usage_ledger (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID, -- lien vers ai_agent_calls.request_id quand applicable
    beneficiary_profile_id UUID REFERENCES profiles(id),
    policy_key TEXT REFERENCES ai_policies(policy_key),
    agent_type TEXT NOT NULL,
    compute_class TEXT NOT NULL DEFAULT 'server', -- 'cache' | 'device' | 'server' (§4.2 usage.route)
    units_reserved INT NOT NULL DEFAULT 0,
    units_consumed INT NOT NULL DEFAULT 0,
    units_refunded INT NOT NULL DEFAULT 0,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_ledger_profile ON ai_usage_ledger (beneficiary_profile_id, created_at DESC);

ALTER TABLE ai_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_policies_select ON ai_policies;
CREATE POLICY ai_policies_select ON ai_policies FOR SELECT USING (true); -- lisible par tous (authenticated + anon), comme access_matrix
DROP POLICY IF EXISTS ai_policies_write ON ai_policies;
CREATE POLICY ai_policies_write ON ai_policies FOR ALL USING (has_admin_role('super_admin')) WITH CHECK (has_admin_role('super_admin'));

DROP POLICY IF EXISTS ai_entitlements_select ON ai_entitlements;
CREATE POLICY ai_entitlements_select ON ai_entitlements FOR SELECT USING (owns_profile(profile_id) OR is_admin_user());
DROP POLICY IF EXISTS ai_entitlements_write ON ai_entitlements;
CREATE POLICY ai_entitlements_write ON ai_entitlements FOR ALL USING (is_admin_user()) WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS ai_usage_ledger_select ON ai_usage_ledger;
CREATE POLICY ai_usage_ledger_select ON ai_usage_ledger FOR SELECT USING (owns_profile(beneficiary_profile_id) OR is_admin_user());
DROP POLICY IF EXISTS ai_usage_ledger_write ON ai_usage_ledger;
CREATE POLICY ai_usage_ledger_write ON ai_usage_ledger FOR INSERT WITH CHECK (is_admin_user());
-- Pas de policy UPDATE/DELETE : append-only, même le service_role (qui bypass RLS) ne doit le faire
-- que via des écritures compensatoires côté application, jamais une réécriture directe.

-- Seed : les policies nommées par le cahier (§6/U7), hiérarchie de priorité reprise de la
-- hiérarchie des paliers d'abonnement (§6.1 du cahier maître : Gratuit < Journalier < Hebdomadaire
-- < Mensuel < Annuel). Aucune valeur numérique de quota inventée.
INSERT INTO ai_policies (policy_key, name, description, priority) VALUES
('FREE', 'Gratuit', 'Palier gratuit permanent — profils avec subscription_tier=''gratuit''.', 0),
('DAY_PASS', 'Journalier', 'Profils avec subscription_tier=''journalier''.', 1),
('WEEKLY', 'Hebdomadaire', 'Profils avec subscription_tier=''hebdomadaire''.', 2),
('MONTHLY_STANDARD', 'Mensuel', 'Profils avec subscription_tier=''mensuel''.', 3),
('MONTHLY_PREMIUM', 'Annuel', 'Profils avec subscription_tier=''annuel'' (accès le plus complet — §6.1 du cahier maître).', 4),
('SCHOOL_PLAN', 'Établissement', 'Réservé aux accords établissement — non branché automatiquement depuis subscription_tier.', 3),
('PROMOTIONAL', 'Promotionnel', 'Codes promo/parrainage temporaires — non branché automatiquement depuis subscription_tier.', 2)
ON CONFLICT (policy_key) DO NOTHING;

-- Résout l'entitlement de CHAQUE profil actif existant depuis son vrai subscription_tier — pas une
-- migration de données fictives, un vrai calcul depuis l'état réel de la table profiles.
INSERT INTO ai_entitlements (profile_id, policy_key, source)
SELECT p.id,
    CASE p.subscription_tier
        WHEN 'gratuit' THEN 'FREE'
        WHEN 'journalier' THEN 'DAY_PASS'
        WHEN 'hebdomadaire' THEN 'WEEKLY'
        WHEN 'mensuel' THEN 'MONTHLY_STANDARD'
        WHEN 'annuel' THEN 'MONTHLY_PREMIUM'
        ELSE 'FREE'
    END,
    'subscription_tier'
FROM profiles p
WHERE p.status = 'actif'
ON CONFLICT (profile_id) DO NOTHING;
