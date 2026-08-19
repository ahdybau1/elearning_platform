-- Migration 11: Liaison Auth pour les comptes parents
--
-- parent_accounts n'avait jamais reçu de colonne auth_user_id — impossible de relier un compte
-- parent à une session Supabase Auth réelle (CDC section 2.16 : le parent a son propre compte et se
-- connecte lui-même). La policy de lecture restait donc admin-only en attendant cette étape.
--
-- Rejouable sans erreur.

ALTER TABLE parent_accounts ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id);

DROP POLICY IF EXISTS parent_accounts_admin_select ON parent_accounts;
DROP POLICY IF EXISTS parent_accounts_select ON parent_accounts;
CREATE POLICY parent_accounts_select ON parent_accounts
    FOR SELECT USING (auth_user_id = auth.uid() OR is_admin_user());

DROP POLICY IF EXISTS parent_accounts_insert ON parent_accounts;
CREATE POLICY parent_accounts_insert ON parent_accounts
    FOR INSERT WITH CHECK (auth_user_id = auth.uid() OR is_admin_user());

DROP POLICY IF EXISTS parent_accounts_update ON parent_accounts;
CREATE POLICY parent_accounts_update ON parent_accounts
    FOR UPDATE USING (auth_user_id = auth.uid() OR is_admin_user());

DROP POLICY IF EXISTS parent_accounts_delete ON parent_accounts;
CREATE POLICY parent_accounts_delete ON parent_accounts
    FOR DELETE USING (is_admin_user());
