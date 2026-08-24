-- Migration 43: Tickets support réellement identifiés élève/parent (CDC §9)
--
-- support_tickets.account_id référençait uniquement accounts — un parent (identité dans une table
-- séparée, parent_accounts) n'avait littéralement aucune ligne valide à renseigner. requester_type
-- existait déjà ('eleve'/'parent') mais rien ne pouvait jamais produire un ticket 'parent' réel.
--
-- Rejouable sans erreur.

CREATE OR REPLACE FUNCTION owns_parent_account(p_parent_account_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM parent_accounts WHERE id = p_parent_account_id AND auth_user_id = auth.uid() AND is_active = true
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

ALTER TABLE support_tickets ALTER COLUMN account_id DROP NOT NULL;
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS parent_account_id UUID REFERENCES parent_accounts(id);

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS support_tickets_requester_xor;
ALTER TABLE support_tickets ADD CONSTRAINT support_tickets_requester_xor
    CHECK ((account_id IS NOT NULL) <> (parent_account_id IS NOT NULL));

DROP POLICY IF EXISTS support_tickets_select ON support_tickets;
CREATE POLICY support_tickets_select ON support_tickets FOR SELECT USING (
    owns_account(account_id) OR owns_parent_account(parent_account_id) OR is_admin_user()
);
DROP POLICY IF EXISTS support_tickets_insert ON support_tickets;
CREATE POLICY support_tickets_insert ON support_tickets FOR INSERT WITH CHECK (
    owns_account(account_id) OR owns_parent_account(parent_account_id)
);
