-- Migration 41: Demandes réelles d'export/suppression de données (CDC §11.1, droit à l'oubli)
--
-- L'écran Paramètres redirigeait ces demandes vers un ticket support générique (catégorie 'autre'),
-- sans jamais les distinguer d'un problème technique quelconque. Table dédiée, même logique que
-- refund_requests déjà dans le schéma : la décision/traitement reste une action admin manuelle
-- (irréversible), jamais une suppression automatique déclenchée côté client.
--
-- Rejouable sans erreur.

CREATE TABLE IF NOT EXISTS data_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL CHECK (request_type IN ('export', 'deletion')),
    status TEXT NOT NULL DEFAULT 'en_attente' CHECK (status IN ('en_attente', 'traitee', 'refusee')),
    admin_note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

ALTER TABLE data_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS data_requests_select ON data_requests;
CREATE POLICY data_requests_select ON data_requests FOR SELECT USING (owns_account(account_id) OR is_admin_user());
DROP POLICY IF EXISTS data_requests_insert ON data_requests;
CREATE POLICY data_requests_insert ON data_requests FOR INSERT WITH CHECK (owns_account(account_id));
DROP POLICY IF EXISTS data_requests_admin_update ON data_requests;
CREATE POLICY data_requests_admin_update ON data_requests FOR UPDATE USING (is_admin_user());
